class PreMatch::SyncMarketsJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 1

  def perform
    @bet_balancer = BetBalancer.new

    http_status, fixtures_data = @bet_balancer.get_updates

    if http_status != 200
      Rails.logger.error("Failed to fetch updates from BetBalancer: HTTP #{http_status}")
      return
    end

    fixtures_data.remove_namespaces!
    process_updates(fixtures_data)
  end

  def process_updates(fixtures_data)
    fixtures_data.xpath("//Match").each do |match_node|
      event_id = match_node["BetbalancerMatchID"]&.to_i
      next unless event_id

      fixture = Fixture.find_by(event_id: event_id)
      next unless fixture

      # 1. Update fixture info (date, status)
      update_fixture_info(fixture, match_node)

      # 2. Update odds
      update_pre_market_odds(fixture, match_node)

      # 3. Check if fixture needs settlement (<BetResult> exists)
      bet_result_node = match_node.at_xpath("BetResult")
      if bet_result_node.present?
        settle_pre_market(fixture, bet_result_node)
      end
    end
  end

  def update_fixture_info(fixture, match_node)
    fixture_node = match_node.xpath("Fixture")
    return unless fixture_node.present?

    update_attrs = {}

    # Check for date change
    match_date_node = fixture_node.xpath("DateInfo/MatchDate")
    if match_date_node.present?
      new_date = match_date_node.text.to_datetime.strftime("%Y-%m-%d %H:%M:%S") rescue nil
      if new_date && fixture.start_date != new_date
        update_attrs[:start_date] = new_date
        Rails.logger.info("Fixture #{fixture.id} date changed: #{fixture.start_date} -> #{new_date}")
      end
    end

    # Check for status change
    status_off = fixture_node.xpath("StatusInfo/Off").text
    if status_off == "1" && fixture.status != "1"
      update_attrs[:status] = "1"
      update_attrs[:match_status] = "ended"
    end

    fixture.update(update_attrs) if update_attrs.any?
  end

  def update_pre_market_odds(fixture, match_node)
    # Index existing markets for fast lookup
    existing_markets = PreMarket.where(fixture_id: fixture.id)
                                .index_by { |m| [m.market_identifier.to_s, m.specifier] }

    match_node.xpath("MatchOdds/Bet").each do |market_node|
      ext_market_id = market_node["OddsType"]

      # Group odds by specifier
      odds_by_specifier = {}

      market_node.xpath("Odds").each do |odd_node|
        outcome = odd_node["OutCome"]
        outcome_id = odd_node["OutComeId"]&.to_i
        value = odd_node.text

        # Skip OFF odds
        next if value == "OFF"

        specifier = odd_node["SpecialBetValue"].presence

        odds_by_specifier[specifier] ||= {}
        odds_by_specifier[specifier][outcome] = {
          "odd" => value.to_f,
          "outcome_id" => outcome_id
        }.compact
      end

      # Update each specifier's market
      odds_by_specifier.each do |specifier, odds_hash|
        market = existing_markets[[ext_market_id, specifier]]

        if market
          # Update existing market
          unless market.update(odds: odds_hash)
            Rails.logger.error("Failed to update PreMarket #{market.id}: #{market.errors.full_messages.join(', ')}")
          end
        else
          # Create new market if it doesn't exist
          new_market = PreMarket.create(
            fixture_id: fixture.id,
            market_identifier: ext_market_id,
            specifier: specifier,
            odds: odds_hash,
            status: "active"
          )

          unless new_market.persisted?
            Rails.logger.error("Failed to create PreMarket for fixture #{fixture.id}, market #{ext_market_id}: #{new_market.errors.full_messages.join(', ')}")
          else
            # Add to cache for potential future lookups in same batch
            existing_markets[[ext_market_id, specifier]] = new_market
          end
        end
      end
    end
  end

  def settle_pre_market(fixture, bet_result_node)
    existing_markets = PreMarket.where(fixture_id: fixture.id)
                                .index_by { |m| [m.market_identifier, m.specifier] }

    # Group outcomes by [market_identifier, specifier]
    # XML: <BetResult><W OddsType="186" OutComeId="4" OutCome="..."/><L .../></BetResult>
    markets_results = {}

    bet_result_node.xpath("*").each do |outcome_node|
      market_identifier = outcome_node["OddsType"]
      specifier = outcome_node["SpecialBetValue"].presence
      outcome = outcome_node["OutCome"]
      status = outcome_node.name  # "W" or "L"
      void_factor = outcome_node["VoidFactor"]&.to_f || 0.0
      outcome_id = outcome_node["OutComeId"]&.to_i

      key = [market_identifier, specifier]
      markets_results[key] ||= {}
      markets_results[key][outcome] = {
        "status" => status,
        "void_factor" => void_factor,
        "outcome_id" => outcome_id
      }
    end

    # Settle each market
    markets_results.each do |(market_identifier, specifier), results|
      market = existing_markets[[market_identifier, specifier]]

      unless market
        Rails.logger.warn("PreMarket not found for settlement: fixture=#{fixture.id}, market_identifier=#{market_identifier}, specifier=#{specifier}")
        next
      end

      # Skip if already settled
      next if market.status == "settled"

      unless market.update(results: results, status: "settled")
        Rails.logger.error("Failed to settle PreMarket #{market.id}: #{market.errors.full_messages.join(', ')}")
        next
      end

      Rails.logger.info("Settled PreMarket #{market.id} (#{market_identifier}|#{specifier}) for fixture #{fixture.id}")

      # Enqueue job to close settled bets
      CloseSettledBetsJob.perform_async(fixture.id, market.id, 'PreMatch')
    end
  end
end
