class PreMatch::PullSettlementsJob
  include Sidekiq::Job
  sidekiq_options queue: :high, retry: 1

  CHANNEL = 'live_feed_commands'

  def perform
    @bet_balancer = BetBalancerService.new

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
      if new_date && fixture.start_time != new_date
        update_attrs[:start_time] = new_date
        Rails.logger.info("Fixture #{fixture.id} date changed: #{fixture.start_time} -> #{new_date}")
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

      # # Skip if already settled
      # next if market.status == "settled"

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

# <?xml version="1.0" encoding="UTF-8"?>
# <BetbalancerBetData>
# 	<Timestamp CreatedTime="2026-01-28T15:40:40.002Z" TimeZone="UTC" />
# 	<Sports>
# 		<Sport BetbalancerSportID="1">
# 			<Texts>
# 				<Text Language="BET">
# 					<Value>Soccer</Value>
# 				</Text>
# 				<Text Language="en">
# 					<Value>Soccer</Value>
# 				</Text>
# 				<Text Language="it">
# 					<Value>Calcio</Value>
# 				</Text>
# 			</Texts>
# 			<Category BetbalancerCategoryID="13">
# 				<Texts>
# 					<Text Language="BET">
# 						<Value>Brazil</Value>
# 					</Text>
# 					<Text Language="en">
# 						<Value>Brazil</Value>
# 					</Text>
# 					<Text Language="it">
# 						<Value>Brasile</Value>
# 					</Text>
# 				</Texts>
# 				<Tournament BetbalancerTournamentID="27983">
# 					<Texts>
# 						<Text Language="BET">
# 							<Value>Amazonense</Value>
# 						</Text>
# 						<Text Language="en">
# 							<Value>Amazonense</Value>
# 						</Text>
# 						<Text Language="it">
# 							<Value>Amazonense</Value>
# 						</Text>
# 					</Texts>
# 					<SuperTournament Name="Amazonense" SuperID="27983"/>
# 					<Match BetbalancerMatchID="66169134">
# 						<Fixture>
# 							<Competitors>
# 								<Texts>
# 									<Text ID="904597"  SUPERID="904597" Type="1">
# 										<Text Language="BET">
# 											<Value>Parintins FC AM</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Parintins FC AM</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Parintins FC AM</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 								<Texts>
# 									<Text ID="21859"  SUPERID="21859" Type="2">
# 										<Text Language="BET">
# 											<Value>Nacional FC AM</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Nacional FC AM</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Nacional Am</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 							</Competitors>
# 							<DateInfo>
# 								<MatchDate Changed="0">2026-01-28T19:30:00.000Z</MatchDate>
# 							</DateInfo>
# 							<StatusInfo>
# 								<Off>0</Off>
# 							</StatusInfo>
# 							<NeutralGround>0</NeutralGround>
# 						</Fixture>
# 						<MatchOdds>
# 							<Bet OddsType="1">
# 								<Odds OutCome="{$competitor1}" OutComeId="1">3.2</Odds>
# 								<Odds OutCome="draw" OutComeId="2">3.06</Odds>
# 								<Odds OutCome="{$competitor2}" OutComeId="3">2.38</Odds>
# 							</Bet>
# 							<Bet OddsType="10">
# 								<Odds OutCome="{$competitor1} or draw" OutComeId="9">1.48</Odds>
# 								<Odds OutCome="{$competitor1} or {$competitor2}" OutComeId="10">1.32</Odds>
# 								<Odds OutCome="draw or {$competitor2}" OutComeId="11">1.3</Odds>
# 							</Bet>
# 							<Bet OddsType="11">
# 								<Odds OutCome="{$competitor1}" OutComeId="4">2.15</Odds>
# 								<Odds OutCome="{$competitor2}" OutComeId="5">1.62</Odds>
# 							</Bet>
# 							<Bet OddsType="12">
# 								<Odds OutCome="draw" OutComeId="776">2.1</Odds>
# 								<Odds OutCome="{$competitor2}" OutComeId="778">1.66</Odds>
# 							</Bet>
# 							<Bet OddsType="13">
# 								<Odds OutCome="{$competitor1}" OutComeId="780">1.9</Odds>
# 								<Odds OutCome="draw" OutComeId="782">1.81</Odds>
# 							</Bet>
# 							<Bet OddsType="14">
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="4:0">1.01</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="3:0">1.02</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="0:3">19.75</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="0:1">6.28</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="0:2">13.42</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="1:0">1.47</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="2:0">1.11</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="0:3">6.51</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="4:0">6.62</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="3:0">6.53</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="0:1">3.93</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="0:2">5.77</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="1:0">3.48</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="2:0">5.1</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="3:0">15.93</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="4:0">20.04</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="0:3">1.01</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="0:1">1.27</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="0:2">1.05</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="1:0">4.31</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="2:0">9.36</Odds>
# 							</Bet>
# 							<Bet OddsType="15">
# 								<Odds OutCome="{$competitor1} by 1" OutComeId="113" variant="variant=sr:winning_margin:3+">4.74</Odds>
# 								<Odds OutCome="{$competitor1} by 2" OutComeId="114" variant="variant=sr:winning_margin:3+">10.81</Odds>
# 								<Odds OutCome="{$competitor1} by 3+" OutComeId="115" variant="variant=sr:winning_margin:3+">26.53</Odds>
# 								<Odds OutCome="{$competitor2} by 1" OutComeId="116" variant="variant=sr:winning_margin:3+">3.93</Odds>
# 								<Odds OutCome="{$competitor2} by 2" OutComeId="117" variant="variant=sr:winning_margin:3+">7.39</Odds>
# 								<Odds OutCome="{$competitor2} by 3+" OutComeId="118" variant="variant=sr:winning_margin:3+">14.02</Odds>
# 								<Odds OutCome="draw" OutComeId="119" variant="variant=sr:winning_margin:3+">2.87</Odds>
# 							</Bet>
# 							<Bet OddsType="16">
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0">2.15</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0.25">1.76</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0.75">1.4</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="1">1.23</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0.5">1.56</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="1.25">1.19</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="1.5">1.16</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="1.75">1.1</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-0.25">2.58</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-1">5.56</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-1.25">5.99</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-0.5">2.99</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-0.75">3.78</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-1.75">8.12</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-1.5">6.39</Odds>
# 								<Odds OutCome="-1" OutComeId="1714" SpecialBetValue="2">OFF</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0">1.62</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0.25">1.96</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0.5">2.28</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0.75">2.75</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="1">3.72</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="1.75">5.85</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="1.5">4.55</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="1.25">4.15</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-0.25">1.44</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-1">1.11</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-0.75">1.23</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-0.5">1.34</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-1.75">1.05</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-1.5">1.08</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-1.25">1.1</Odds>
# 								<Odds OutCome="-1" OutComeId="1715" SpecialBetValue="2">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="18">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.5">1.09</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.75">1.1</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1">1.13</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.25">1.28</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="4.25">7.58</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="4.75">9.33</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="5">11.13</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="4">7.32</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="3.5">4.22</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.5">2.33</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.5">1.43</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="5.5">11.26</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="4.5">7.85</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.75">1.55</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.25">2.04</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2">1.74</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.75">2.75</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="3">3.53</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="3.25">3.88</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="3.75">5.28</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.5">6.26</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1">5.21</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.25">3.36</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.75">5.76</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="5">1.01</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="4.75">1.03</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="4.25">1.05</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="4">1.06</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.5">2.63</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.5">1.54</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="3.5">1.19</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="4.5">1.05</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="5.5">1.01</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.75">2.31</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2">1.97</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.25">1.69</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="3.25">1.22</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="3">1.25</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.75">1.4</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="3.75">1.12</Odds>
# 							</Bet>
# 							<Bet OddsType="19">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.5">1.47</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.5">3.21</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.5">7.62</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="3.5">11.77</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.5">2.49</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.5">1.3</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.5">1.05</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="3.5">1.01</Odds>
# 							</Bet>
# 							<Bet OddsType="20">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.5">1.34</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.5">2.58</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.5">5.8</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="3.5">10.66</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.5">3</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.5">1.45</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.5">1.1</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="3.5">1.01</Odds>
# 							</Bet>
# 							<Bet OddsType="21">
# 								<Odds OutCome="0" OutComeId="68" variant="variant=sr:exact_goals:6+">7.18</Odds>
# 								<Odds OutCome="1" OutComeId="69" variant="variant=sr:exact_goals:6+">3.72</Odds>
# 								<Odds OutCome="2" OutComeId="70" variant="variant=sr:exact_goals:6+">3.13</Odds>
# 								<Odds OutCome="3" OutComeId="71" variant="variant=sr:exact_goals:6+">4.29</Odds>
# 								<Odds OutCome="4" OutComeId="72" variant="variant=sr:exact_goals:6+">7.09</Odds>
# 								<Odds OutCome="5" OutComeId="73" variant="variant=sr:exact_goals:6+">16.01</Odds>
# 								<Odds OutCome="6+" OutComeId="74" variant="variant=sr:exact_goals:6+">28.26</Odds>
# 								<Odds OutCome="0" OutComeId="1336" variant="variant=sr:exact_goals:5+">7.17</Odds>
# 								<Odds OutCome="1" OutComeId="1337" variant="variant=sr:exact_goals:5+">3.72</Odds>
# 								<Odds OutCome="2" OutComeId="1338" variant="variant=sr:exact_goals:5+">3.12</Odds>
# 								<Odds OutCome="3" OutComeId="1339" variant="variant=sr:exact_goals:5+">4.29</Odds>
# 								<Odds OutCome="4" OutComeId="1340" variant="variant=sr:exact_goals:5+">7.08</Odds>
# 								<Odds OutCome="5+" OutComeId="1341" variant="variant=sr:exact_goals:5+">10.3</Odds>
# 							</Bet>
# 							<Bet OddsType="23">
# 								<Odds OutCome="0" OutComeId="88" variant="variant=sr:exact_goals:3+">2.54</Odds>
# 								<Odds OutCome="1" OutComeId="89" variant="variant=sr:exact_goals:3+">2.48</Odds>
# 								<Odds OutCome="2" OutComeId="90" variant="variant=sr:exact_goals:3+">4.78</Odds>
# 								<Odds OutCome="3+" OutComeId="91" variant="variant=sr:exact_goals:3+">10.6</Odds>
# 							</Bet>
# 							<Bet OddsType="24">
# 								<Odds OutCome="0" OutComeId="88" variant="variant=sr:exact_goals:3+">3.12</Odds>
# 								<Odds OutCome="1" OutComeId="89" variant="variant=sr:exact_goals:3+">2.55</Odds>
# 								<Odds OutCome="2" OutComeId="90" variant="variant=sr:exact_goals:3+">4.09</Odds>
# 								<Odds OutCome="3+" OutComeId="91" variant="variant=sr:exact_goals:3+">7.01</Odds>
# 							</Bet>
# 							<Bet OddsType="25">
# 								<Odds OutCome="0-1" OutComeId="1121" variant="variant=sr:point_range:6+">2.67</Odds>
# 								<Odds OutCome="2-3" OutComeId="1122" variant="variant=sr:point_range:6+">1.98</Odds>
# 								<Odds OutCome="4-5" OutComeId="1123" variant="variant=sr:point_range:6+">5.32</Odds>
# 								<Odds OutCome="6+" OutComeId="1124" variant="variant=sr:point_range:6+">30</Odds>
# 								<Odds OutCome="0-1" OutComeId="1342" variant="variant=sr:goal_range:7+">2.67</Odds>
# 								<Odds OutCome="2-3" OutComeId="1343" variant="variant=sr:goal_range:7+">1.98</Odds>
# 								<Odds OutCome="4-6" OutComeId="1344" variant="variant=sr:goal_range:7+">4.76</Odds>
# 								<Odds OutCome="7+" OutComeId="1345" variant="variant=sr:goal_range:7+">30</Odds>
# 							</Bet>
# 							<Bet OddsType="26">
# 								<Odds OutCome="odd" OutComeId="70">1.93</Odds>
# 								<Odds OutCome="even" OutComeId="72">1.78</Odds>
# 							</Bet>
# 							<Bet OddsType="27">
# 								<Odds OutCome="odd" OutComeId="70">2.1</Odds>
# 								<Odds OutCome="even" OutComeId="72">1.66</Odds>
# 							</Bet>
# 							<Bet OddsType="28">
# 								<Odds OutCome="odd" OutComeId="70">2.01</Odds>
# 								<Odds OutCome="even" OutComeId="72">1.72</Odds>
# 							</Bet>
# 							<Bet OddsType="29">
# 								<Odds OutCome="yes" OutComeId="74">1.99</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.73</Odds>
# 							</Bet>
# 							<Bet OddsType="30">
# 								<Odds OutCome="none" OutComeId="784">7.94</Odds>
# 								<Odds OutCome="only {$competitor1}" OutComeId="788">5.12</Odds>
# 								<Odds OutCome="only {$competitor2}" OutComeId="790">3.73</Odds>
# 								<Odds OutCome="both teams" OutComeId="792">2.04</Odds>
# 							</Bet>
# 							<Bet OddsType="31">
# 								<Odds OutCome="yes" OutComeId="74">3</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.34</Odds>
# 							</Bet>
# 							<Bet OddsType="32">
# 								<Odds OutCome="yes" OutComeId="74">2.49</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.47</Odds>
# 							</Bet>
# 							<Bet OddsType="33">
# 								<Odds OutCome="yes" OutComeId="74">4.52</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.16</Odds>
# 							</Bet>
# 							<Bet OddsType="34">
# 								<Odds OutCome="yes" OutComeId="74">3.47</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.26</Odds>
# 							</Bet>
# 							<Bet OddsType="35">
# 								<Odds OutCome="{$competitor1} &amp; yes" OutComeId="78">7.13</Odds>
# 								<Odds OutCome="{$competitor1} &amp; no" OutComeId="80">4.68</Odds>
# 								<Odds OutCome="draw &amp; yes" OutComeId="82">4.29</Odds>
# 								<Odds OutCome="draw &amp; no" OutComeId="84">7.2</Odds>
# 								<Odds OutCome="{$competitor2} &amp; yes" OutComeId="86">5.45</Odds>
# 								<Odds OutCome="{$competitor2} &amp; no" OutComeId="88">3.44</Odds>
# 							</Bet>
# 							<Bet OddsType="36">
# 								<Odds OutCome="over {total} &amp; yes" OutComeId="90" SpecialBetValue="2.5">2.59</Odds>
# 								<Odds OutCome="under {total} &amp; yes" OutComeId="92" SpecialBetValue="2.5">5.5</Odds>
# 								<Odds OutCome="over {total} &amp; no" OutComeId="94" SpecialBetValue="2.5">11.11</Odds>
# 								<Odds OutCome="under {total} &amp; no" OutComeId="96" SpecialBetValue="2.5">1.85</Odds>
# 							</Bet>
# 							<Bet OddsType="37">
# 								<Odds OutCome="{$competitor1} &amp; under {total}" OutComeId="794" SpecialBetValue="4.5">3.13</Odds>
# 								<Odds OutCome="{$competitor1} &amp; under {total}" OutComeId="794" SpecialBetValue="2.5">5.35</Odds>
# 								<Odds OutCome="{$competitor1} &amp; under {total}" OutComeId="794" SpecialBetValue="3.5">3.52</Odds>
# 								<Odds OutCome="{$competitor1} &amp; under {total}" OutComeId="794" SpecialBetValue="1.5">8</Odds>
# 								<Odds OutCome="{$competitor1} &amp; over {total}" OutComeId="796" SpecialBetValue="2.5">5.93</Odds>
# 								<Odds OutCome="{$competitor1} &amp; over {total}" OutComeId="796" SpecialBetValue="3.5">14.32</Odds>
# 								<Odds OutCome="{$competitor1} &amp; over {total}" OutComeId="796" SpecialBetValue="1.5">4.37</Odds>
# 								<Odds OutCome="{$competitor1} &amp; over {total}" OutComeId="796" SpecialBetValue="4.5">27</Odds>
# 								<Odds OutCome="draw &amp; under {total}" OutComeId="798" SpecialBetValue="3.5">3.27</Odds>
# 								<Odds OutCome="draw &amp; under {total}" OutComeId="798" SpecialBetValue="4.5">2.77</Odds>
# 								<Odds OutCome="draw &amp; under {total}" OutComeId="798" SpecialBetValue="1.5">7.18</Odds>
# 								<Odds OutCome="draw &amp; under {total}" OutComeId="798" SpecialBetValue="2.5">3.3</Odds>
# 								<Odds OutCome="draw &amp; over {total}" OutComeId="800" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="draw &amp; over {total}" OutComeId="800" SpecialBetValue="1.5">4.28</Odds>
# 								<Odds OutCome="draw &amp; over {total}" OutComeId="800" SpecialBetValue="2.5">15.31</Odds>
# 								<Odds OutCome="draw &amp; over {total}" OutComeId="800" SpecialBetValue="3.5">15.11</Odds>
# 								<Odds OutCome="{$competitor2} &amp; under {total}" OutComeId="802" SpecialBetValue="4.5">2.39</Odds>
# 								<Odds OutCome="{$competitor2} &amp; under {total}" OutComeId="802" SpecialBetValue="2.5">4.16</Odds>
# 								<Odds OutCome="{$competitor2} &amp; under {total}" OutComeId="802" SpecialBetValue="3.5">2.73</Odds>
# 								<Odds OutCome="{$competitor2} &amp; under {total}" OutComeId="802" SpecialBetValue="1.5">6.63</Odds>
# 								<Odds OutCome="{$competitor2} &amp; over {total}" OutComeId="804" SpecialBetValue="3.5">9.34</Odds>
# 								<Odds OutCome="{$competitor2} &amp; over {total}" OutComeId="804" SpecialBetValue="2.5">4.23</Odds>
# 								<Odds OutCome="{$competitor2} &amp; over {total}" OutComeId="804" SpecialBetValue="1.5">3.1</Odds>
# 								<Odds OutCome="{$competitor2} &amp; over {total}" OutComeId="804" SpecialBetValue="4.5">18.09</Odds>
# 							</Bet>
# 							<Bet OddsType="41">
# 								<Odds OutCome="0:0" OutComeId="110" variant="score=0:0">6.52</Odds>
# 								<Odds OutCome="1:0" OutComeId="114" variant="score=0:0">7.25</Odds>
# 								<Odds OutCome="2:0" OutComeId="116" variant="score=0:0">13.85</Odds>
# 								<Odds OutCome="3:0" OutComeId="118" variant="score=0:0">30</Odds>
# 								<Odds OutCome="4:0" OutComeId="120" variant="score=0:0">30</Odds>
# 								<Odds OutCome="5:0" OutComeId="122" variant="score=0:0">30</Odds>
# 								<Odds OutCome="6:0" OutComeId="124" variant="score=0:0">30</Odds>
# 								<Odds OutCome="0:1" OutComeId="126" variant="score=0:0">6.02</Odds>
# 								<Odds OutCome="1:1" OutComeId="128" variant="score=0:0">5.28</Odds>
# 								<Odds OutCome="2:1" OutComeId="130" variant="score=0:0">11.17</Odds>
# 								<Odds OutCome="3:1" OutComeId="132" variant="score=0:0">30</Odds>
# 								<Odds OutCome="4:1" OutComeId="134" variant="score=0:0">30</Odds>
# 								<Odds OutCome="5:1" OutComeId="136" variant="score=0:0">30</Odds>
# 								<Odds OutCome="0:2" OutComeId="138" variant="score=0:0">9.49</Odds>
# 								<Odds OutCome="1:2" OutComeId="140" variant="score=0:0">9.25</Odds>
# 								<Odds OutCome="2:2" OutComeId="142" variant="score=0:0">15.87</Odds>
# 								<Odds OutCome="3:2" OutComeId="144" variant="score=0:0">30</Odds>
# 								<Odds OutCome="4:2" OutComeId="146" variant="score=0:0">30</Odds>
# 								<Odds OutCome="0:3" OutComeId="148" variant="score=0:0">22.43</Odds>
# 								<Odds OutCome="1:3" OutComeId="150" variant="score=0:0">21.86</Odds>
# 								<Odds OutCome="2:3" OutComeId="152" variant="score=0:0">30</Odds>
# 								<Odds OutCome="3:3" OutComeId="154" variant="score=0:0">30</Odds>
# 								<Odds OutCome="0:4" OutComeId="156" variant="score=0:0">30</Odds>
# 								<Odds OutCome="1:4" OutComeId="158" variant="score=0:0">30</Odds>
# 								<Odds OutCome="2:4" OutComeId="160" variant="score=0:0">30</Odds>
# 								<Odds OutCome="0:5" OutComeId="162" variant="score=0:0">30</Odds>
# 								<Odds OutCome="1:5" OutComeId="164" variant="score=0:0">30</Odds>
# 								<Odds OutCome="0:6" OutComeId="166" variant="score=0:0">30</Odds>
# 							</Bet>
# 							<Bet OddsType="45">
# 								<Odds OutCome="0:0" OutComeId="274">5.95</Odds>
# 								<Odds OutCome="1:0" OutComeId="276">6.6</Odds>
# 								<Odds OutCome="2:0" OutComeId="278">12.52</Odds>
# 								<Odds OutCome="3:0" OutComeId="280">30</Odds>
# 								<Odds OutCome="4:0" OutComeId="282">30</Odds>
# 								<Odds OutCome="0:1" OutComeId="284">5.5</Odds>
# 								<Odds OutCome="1:1" OutComeId="286">4.83</Odds>
# 								<Odds OutCome="2:1" OutComeId="288">10.12</Odds>
# 								<Odds OutCome="3:1" OutComeId="290">28.86</Odds>
# 								<Odds OutCome="4:1" OutComeId="292">30</Odds>
# 								<Odds OutCome="0:2" OutComeId="294">8.61</Odds>
# 								<Odds OutCome="1:2" OutComeId="296">8.4</Odds>
# 								<Odds OutCome="2:2" OutComeId="298">14.33</Odds>
# 								<Odds OutCome="3:2" OutComeId="300">30</Odds>
# 								<Odds OutCome="4:2" OutComeId="302">30</Odds>
# 								<Odds OutCome="0:3" OutComeId="304">20.21</Odds>
# 								<Odds OutCome="1:3" OutComeId="306">19.69</Odds>
# 								<Odds OutCome="2:3" OutComeId="308">30</Odds>
# 								<Odds OutCome="3:3" OutComeId="310">30</Odds>
# 								<Odds OutCome="4:3" OutComeId="312">30</Odds>
# 								<Odds OutCome="0:4" OutComeId="314">30</Odds>
# 								<Odds OutCome="1:4" OutComeId="316">30</Odds>
# 								<Odds OutCome="2:4" OutComeId="318">30</Odds>
# 								<Odds OutCome="3:4" OutComeId="320">30</Odds>
# 								<Odds OutCome="4:4" OutComeId="322">30</Odds>
# 								<Odds OutCome="other" OutComeId="324">30</Odds>
# 							</Bet>
# 							<Bet OddsType="46">
# 								<Odds OutCome="0:0 0:0" OutComeId="326">4.73</Odds>
# 								<Odds OutCome="0:0 0:1" OutComeId="328">7.13</Odds>
# 								<Odds OutCome="0:0 0:2" OutComeId="330">19.02</Odds>
# 								<Odds OutCome="0:0 0:3" OutComeId="332">30</Odds>
# 								<Odds OutCome="0:0 1:0" OutComeId="334">8.38</Odds>
# 								<Odds OutCome="0:0 1:1" OutComeId="336">11.91</Odds>
# 								<Odds OutCome="0:0 1:2" OutComeId="338">30</Odds>
# 								<Odds OutCome="0:0 2:0" OutComeId="340">26.92</Odds>
# 								<Odds OutCome="0:0 2:1" OutComeId="342">30</Odds>
# 								<Odds OutCome="0:0 3:0" OutComeId="344">30</Odds>
# 								<Odds OutCome="0:0 4+" OutComeId="346">30</Odds>
# 								<Odds OutCome="0:1 0:1" OutComeId="348">9.85</Odds>
# 								<Odds OutCome="0:1 0:2" OutComeId="350">13.6</Odds>
# 								<Odds OutCome="0:1 0:3" OutComeId="352">30</Odds>
# 								<Odds OutCome="0:1 1:1" OutComeId="354">13.61</Odds>
# 								<Odds OutCome="0:1 1:2" OutComeId="356">23.26</Odds>
# 								<Odds OutCome="0:1 2:1" OutComeId="358">30</Odds>
# 								<Odds OutCome="0:1 4+" OutComeId="360">17.78</Odds>
# 								<Odds OutCome="0:2 0:2" OutComeId="362">30</Odds>
# 								<Odds OutCome="0:2 0:3" OutComeId="364">30</Odds>
# 								<Odds OutCome="0:2 1:2" OutComeId="366">30</Odds>
# 								<Odds OutCome="0:2 4+" OutComeId="368">23.29</Odds>
# 								<Odds OutCome="0:3 0:3" OutComeId="370">30</Odds>
# 								<Odds OutCome="0:3 4+" OutComeId="372">30</Odds>
# 								<Odds OutCome="1:0 1:0" OutComeId="374">12.2</Odds>
# 								<Odds OutCome="1:0 1:1" OutComeId="376">14.1</Odds>
# 								<Odds OutCome="1:0 1:2" OutComeId="378">30</Odds>
# 								<Odds OutCome="1:0 2:0" OutComeId="380">20.06</Odds>
# 								<Odds OutCome="1:0 2:1" OutComeId="382">28.76</Odds>
# 								<Odds OutCome="1:0 3:0" OutComeId="384">30</Odds>
# 								<Odds OutCome="1:0 4+" OutComeId="386">20.84</Odds>
# 								<Odds OutCome="1:1 1:1" OutComeId="388">17.37</Odds>
# 								<Odds OutCome="1:1 1:2" OutComeId="390">28.61</Odds>
# 								<Odds OutCome="1:1 2:1" OutComeId="392">30</Odds>
# 								<Odds OutCome="1:1 4+" OutComeId="394">16.28</Odds>
# 								<Odds OutCome="1:2 1:2" OutComeId="396">30</Odds>
# 								<Odds OutCome="1:2 4+" OutComeId="398">26.72</Odds>
# 								<Odds OutCome="2:0 2:0" OutComeId="400">30</Odds>
# 								<Odds OutCome="2:0 2:1" OutComeId="402">30</Odds>
# 								<Odds OutCome="2:0 3:0" OutComeId="404">30</Odds>
# 								<Odds OutCome="2:0 4+" OutComeId="406">30</Odds>
# 								<Odds OutCome="2:1 2:1" OutComeId="408">30</Odds>
# 								<Odds OutCome="2:1 4+" OutComeId="410">30</Odds>
# 								<Odds OutCome="3:0 3:0" OutComeId="412">30</Odds>
# 								<Odds OutCome="3:0 4+" OutComeId="414">30</Odds>
# 								<Odds OutCome="4+ 4+" OutComeId="416">25.22</Odds>
# 							</Bet>
# 							<Bet OddsType="47">
# 								<Odds OutCome="{$competitor1}/{$competitor1}" OutComeId="418">5.41</Odds>
# 								<Odds OutCome="{$competitor1}/draw" OutComeId="420">15.4</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2}" OutComeId="422">30</Odds>
# 								<Odds OutCome="draw/{$competitor1}" OutComeId="424">6.88</Odds>
# 								<Odds OutCome="draw/draw" OutComeId="426">4.18</Odds>
# 								<Odds OutCome="draw/{$competitor2}" OutComeId="428">5.47</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1}" OutComeId="430">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw" OutComeId="432">14.88</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2}" OutComeId="434">3.8</Odds>
# 							</Bet>
# 							<Bet OddsType="48">
# 								<Odds OutCome="yes" OutComeId="74">9.22</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.03</Odds>
# 							</Bet>
# 							<Bet OddsType="49">
# 								<Odds OutCome="yes" OutComeId="74">7.06</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.07</Odds>
# 							</Bet>
# 							<Bet OddsType="50">
# 								<Odds OutCome="yes" OutComeId="74">2.09</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.66</Odds>
# 							</Bet>
# 							<Bet OddsType="51">
# 								<Odds OutCome="yes" OutComeId="74">1.74</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.98</Odds>
# 							</Bet>
# 							<Bet OddsType="52">
# 								<Odds OutCome="1st half" OutComeId="436">3.21</Odds>
# 								<Odds OutCome="2nd half" OutComeId="438">2.17</Odds>
# 								<Odds OutCome="equal" OutComeId="440">3.05</Odds>
# 							</Bet>
# 							<Bet OddsType="53">
# 								<Odds OutCome="1st half" OutComeId="436">3.94</Odds>
# 								<Odds OutCome="2nd half" OutComeId="438">2.93</Odds>
# 								<Odds OutCome="equal" OutComeId="440">2.06</Odds>
# 							</Bet>
# 							<Bet OddsType="54">
# 								<Odds OutCome="1st half" OutComeId="436">3.61</Odds>
# 								<Odds OutCome="2nd half" OutComeId="438">2.73</Odds>
# 								<Odds OutCome="equal" OutComeId="440">2.29</Odds>
# 							</Bet>
# 							<Bet OddsType="55">
# 								<Odds OutCome="no/no" OutComeId="806">1.34</Odds>
# 								<Odds OutCome="yes/no" OutComeId="808">5.92</Odds>
# 								<Odds OutCome="yes/yes" OutComeId="810">22.53</Odds>
# 								<Odds OutCome="no/yes" OutComeId="812">4.18</Odds>
# 							</Bet>
# 							<Bet OddsType="56">
# 								<Odds OutCome="yes" OutComeId="74">5.11</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.13</Odds>
# 							</Bet>
# 							<Bet OddsType="57">
# 								<Odds OutCome="yes" OutComeId="74">4.08</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.2</Odds>
# 							</Bet>
# 							<Bet OddsType="58">
# 								<Odds OutCome="yes" OutComeId="74" SpecialBetValue="1.5">7.01</Odds>
# 								<Odds OutCome="no" OutComeId="76" SpecialBetValue="1.5">1.07</Odds>
# 							</Bet>
# 							<Bet OddsType="59">
# 								<Odds OutCome="yes" OutComeId="74" SpecialBetValue="1.5">1.95</Odds>
# 								<Odds OutCome="no" OutComeId="76" SpecialBetValue="1.5">1.76</Odds>
# 							</Bet>
# 							<Bet OddsType="60">
# 								<Odds OutCome="{$competitor1}" OutComeId="1">3.66</Odds>
# 								<Odds OutCome="draw" OutComeId="2">1.88</Odds>
# 								<Odds OutCome="{$competitor2}" OutComeId="3">2.89</Odds>
# 							</Bet>
# 							<Bet OddsType="63">
# 								<Odds OutCome="{$competitor1} or draw" OutComeId="9">1.33</Odds>
# 								<Odds OutCome="{$competitor1} or {$competitor2}" OutComeId="10">1.7</Odds>
# 								<Odds OutCome="draw or {$competitor2}" OutComeId="11">1.23</Odds>
# 							</Bet>
# 							<Bet OddsType="64">
# 								<Odds OutCome="{$competitor1}" OutComeId="4">2.1</Odds>
# 								<Odds OutCome="{$competitor2}" OutComeId="5">1.66</Odds>
# 							</Bet>
# 							<Bet OddsType="65">
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="0:2">30</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="2:0">1.03</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="0:1">14.72</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="1:0">1.3</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="2:0">6.87</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="0:2">7.27</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="0:1">4.01</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="1:0">3.5</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="2:0">30</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="0:2">1.01</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="0:1">1.2</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="1:0">10.23</Odds>
# 							</Bet>
# 							<Bet OddsType="66">
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0">2.1</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0.25">1.54</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0.5">1.35</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="1">1.06</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0.75">1.21</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="1.25">1.05</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-0.5">3.67</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-0.25">2.92</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-0.75">5.09</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0">1.66</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0.25">2.33</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="1">7.09</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0.75">3.99</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0.5">2.96</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-0.5">1.24</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-0.25">1.36</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="1.25">7.68</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-0.75">1.13</Odds>
# 							</Bet>
# 							<Bet OddsType="68">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.5">1.51</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.5">3.28</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.5">7.72</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2">6.84</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.25">7.32</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.75">4.3</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.75">9.57</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="3">11.77</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1">2.22</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.75">1.73</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.25">2.76</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.5">1.05</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.5">1.29</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.5">2.39</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2">1.07</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.75">1.18</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.75">1.03</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.25">1.06</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="3">1.01</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1">1.59</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.75">2</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.25">1.39</Odds>
# 							</Bet>
# 							<Bet OddsType="69">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.5">12.34</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.5">2.51</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.5">8.01</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.5">1.01</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.5">1.47</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.5">1.05</Odds>
# 							</Bet>
# 							<Bet OddsType="70">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.5">11.91</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.5">2.18</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.5">6.57</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.5">1.01</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.5">1.61</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.5">1.08</Odds>
# 							</Bet>
# 							<Bet OddsType="71">
# 								<Odds OutCome="0" OutComeId="85" variant="variant=sr:exact_goals:2+">2.42</Odds>
# 								<Odds OutCome="1" OutComeId="86" variant="variant=sr:exact_goals:2+">2.54</Odds>
# 								<Odds OutCome="2+" OutComeId="87" variant="variant=sr:exact_goals:2+">3.41</Odds>
# 								<Odds OutCome="0" OutComeId="88" variant="variant=sr:exact_goals:3+">2.43</Odds>
# 								<Odds OutCome="1" OutComeId="89" variant="variant=sr:exact_goals:3+">2.55</Odds>
# 								<Odds OutCome="2" OutComeId="90" variant="variant=sr:exact_goals:3+">4.9</Odds>
# 								<Odds OutCome="3+" OutComeId="91" variant="variant=sr:exact_goals:3+">10.85</Odds>
# 							</Bet>
# 							<Bet OddsType="74">
# 								<Odds OutCome="odd" OutComeId="70">2.15</Odds>
# 								<Odds OutCome="even" OutComeId="72">1.62</Odds>
# 							</Bet>
# 							<Bet OddsType="75">
# 								<Odds OutCome="yes" OutComeId="74">5.07</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.13</Odds>
# 							</Bet>
# 							<Bet OddsType="76">
# 								<Odds OutCome="yes" OutComeId="74">1.61</Odds>
# 								<Odds OutCome="no" OutComeId="76">2.18</Odds>
# 							</Bet>
# 							<Bet OddsType="77">
# 								<Odds OutCome="yes" OutComeId="74">1.47</Odds>
# 								<Odds OutCome="no" OutComeId="76">2.51</Odds>
# 							</Bet>
# 							<Bet OddsType="78">
# 								<Odds OutCome="{$competitor1} &amp; yes" OutComeId="78">30</Odds>
# 								<Odds OutCome="{$competitor1} &amp; no" OutComeId="80">4.01</Odds>
# 								<Odds OutCome="draw &amp; yes" OutComeId="82">8.28</Odds>
# 								<Odds OutCome="draw &amp; no" OutComeId="84">2.28</Odds>
# 								<Odds OutCome="{$competitor2} &amp; yes" OutComeId="86">24.56</Odds>
# 								<Odds OutCome="{$competitor2} &amp; no" OutComeId="88">3.15</Odds>
# 							</Bet>
# 							<Bet OddsType="79">
# 								<Odds OutCome="{$competitor1} &amp; under {total}" OutComeId="794" SpecialBetValue="1.5">5.07</Odds>
# 								<Odds OutCome="{$competitor1} &amp; over {total}" OutComeId="796" SpecialBetValue="1.5">11.7</Odds>
# 								<Odds OutCome="draw &amp; under {total}" OutComeId="798" SpecialBetValue="1.5">2.29</Odds>
# 								<Odds OutCome="draw &amp; over {total}" OutComeId="800" SpecialBetValue="1.5">8.38</Odds>
# 								<Odds OutCome="{$competitor2} &amp; under {total}" OutComeId="802" SpecialBetValue="1.5">4.19</Odds>
# 								<Odds OutCome="{$competitor2} &amp; over {total}" OutComeId="804" SpecialBetValue="1.5">8.16</Odds>
# 							</Bet>
# 							<Bet OddsType="81">
# 								<Odds OutCome="0:0" OutComeId="462">1.62</Odds>
# 								<Odds OutCome="1:1" OutComeId="464">4.78</Odds>
# 								<Odds OutCome="2:2" OutComeId="466">30</Odds>
# 								<Odds OutCome="1:0" OutComeId="468">2.94</Odds>
# 								<Odds OutCome="2:0" OutComeId="470">10.78</Odds>
# 								<Odds OutCome="2:1" OutComeId="472">18.82</Odds>
# 								<Odds OutCome="0:1" OutComeId="474">2.52</Odds>
# 								<Odds OutCome="0:2" OutComeId="476">7.42</Odds>
# 								<Odds OutCome="1:2" OutComeId="478">15.51</Odds>
# 								<Odds OutCome="other" OutComeId="480">13.31</Odds>
# 							</Bet>
# 							<Bet OddsType="83">
# 								<Odds OutCome="{$competitor1}" OutComeId="1">3.39</Odds>
# 								<Odds OutCome="draw" OutComeId="2">2.29</Odds>
# 								<Odds OutCome="{$competitor2}" OutComeId="3">2.72</Odds>
# 							</Bet>
# 							<Bet OddsType="85">
# 								<Odds OutCome="{$competitor1} or draw" OutComeId="9">1.4</Odds>
# 								<Odds OutCome="{$competitor1} or {$competitor2}" OutComeId="10">1.53</Odds>
# 								<Odds OutCome="draw or {$competitor2}" OutComeId="11">1.29</Odds>
# 							</Bet>
# 							<Bet OddsType="86">
# 								<Odds OutCome="{$competitor1}" OutComeId="4">2.07</Odds>
# 								<Odds OutCome="{$competitor2}" OutComeId="5">1.68</Odds>
# 							</Bet>
# 							<Bet OddsType="87">
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="0:2">30</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="2:0">1.07</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="0:1">11.75</Odds>
# 								<Odds OutCome="{$competitor1} ({hcp})" OutComeId="1711" SpecialBetValue="1:0">1.41</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="0:2">9.23</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="2:0">7.93</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="0:1">4.22</Odds>
# 								<Odds OutCome="draw ({hcp})" OutComeId="1712" SpecialBetValue="1:0">3.69</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="2:0">27.25</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="0:2">1.04</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="0:1">1.29</Odds>
# 								<Odds OutCome="{$competitor2} ({hcp})" OutComeId="1713" SpecialBetValue="1:0">8.3</Odds>
# 							</Bet>
# 							<Bet OddsType="88">
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0">2.07</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0.25">1.61</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0.5">1.42</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="1">1.11</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="0.75">1.26</Odds>
# 								<Odds OutCome="{$competitor1} ({+hcp})" OutComeId="1714" SpecialBetValue="1.25">1.09</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-0.5">3.25</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-0.25">2.68</Odds>
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-0.75">4.38</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0">1.68</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0.25">2.18</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="1">5.66</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0.75">3.47</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="0.5">2.66</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-0.5">1.29</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-0.25">1.41</Odds>
# 								<Odds OutCome="{$competitor2} ({-hcp})" OutComeId="1715" SpecialBetValue="1.25">6.25</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-0.75">1.17</Odds>
# 							</Bet>
# 							<Bet OddsType="90">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.5">1.32</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.5">5.69</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.5">2.5</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.75">3.14</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2">4.69</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.25">5.21</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="3">10.34</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.75">7.36</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1">1.66</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.75">1.44</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.25">2.09</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.5">3.1</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.5">1.47</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.5">1.11</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.75">1.31</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2">1.15</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.25">1.13</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.75">1.06</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="3">1.02</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.25">1.66</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1">2.09</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.75">2.61</Odds>
# 							</Bet>
# 							<Bet OddsType="91">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.5">2.11</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.5">6.25</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.5">11.76</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.5">1.65</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.5">1.09</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.5">1.01</Odds>
# 							</Bet>
# 							<Bet OddsType="92">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="0.5">1.88</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="1.5">5.1</Odds>
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="2.5">10.89</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="0.5">1.83</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="1.5">1.13</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="2.5">1.01</Odds>
# 							</Bet>
# 							<Bet OddsType="93">
# 								<Odds OutCome="0" OutComeId="85" variant="variant=sr:exact_goals:2+">3.21</Odds>
# 								<Odds OutCome="1" OutComeId="86" variant="variant=sr:exact_goals:2+">2.54</Odds>
# 								<Odds OutCome="2+" OutComeId="87" variant="variant=sr:exact_goals:2+">2.54</Odds>
# 							</Bet>
# 							<Bet OddsType="94">
# 								<Odds OutCome="odd" OutComeId="70">2</Odds>
# 								<Odds OutCome="even" OutComeId="72">1.72</Odds>
# 							</Bet>
# 							<Bet OddsType="95">
# 								<Odds OutCome="yes" OutComeId="74">3.99</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.21</Odds>
# 							</Bet>
# 							<Bet OddsType="96">
# 								<Odds OutCome="yes" OutComeId="74">1.83</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.88</Odds>
# 							</Bet>
# 							<Bet OddsType="97">
# 								<Odds OutCome="yes" OutComeId="74">1.65</Odds>
# 								<Odds OutCome="no" OutComeId="76">2.11</Odds>
# 							</Bet>
# 							<Bet OddsType="98">
# 								<Odds OutCome="0:0" OutComeId="546">2.04</Odds>
# 								<Odds OutCome="0:1" OutComeId="548">2.67</Odds>
# 								<Odds OutCome="0:2" OutComeId="550">6.37</Odds>
# 								<Odds OutCome="1:0" OutComeId="552">3.06</Odds>
# 								<Odds OutCome="1:1" OutComeId="554">4.31</Odds>
# 								<Odds OutCome="1:2" OutComeId="556">11.78</Odds>
# 								<Odds OutCome="2:0" OutComeId="558">8.75</Odds>
# 								<Odds OutCome="2:1" OutComeId="560">13.86</Odds>
# 								<Odds OutCome="2:2" OutComeId="562">30</Odds>
# 								<Odds OutCome="other" OutComeId="564">8.08</Odds>
# 							</Bet>
# 							<Bet OddsType="199">
# 								<Odds OutCome="0:0" OutComeId="1302" variant="variant=sr:correct_score:max:6">5.95</Odds>
# 								<Odds OutCome="0:1" OutComeId="1304" variant="variant=sr:correct_score:max:6">5.5</Odds>
# 								<Odds OutCome="0:2" OutComeId="1305" variant="variant=sr:correct_score:max:6">8.61</Odds>
# 								<Odds OutCome="0:3" OutComeId="1306" variant="variant=sr:correct_score:max:6">20.21</Odds>
# 								<Odds OutCome="0:4" OutComeId="1307" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="0:5" OutComeId="1308" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="0:6" OutComeId="1309" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="1:0" OutComeId="1310" variant="variant=sr:correct_score:max:6">6.61</Odds>
# 								<Odds OutCome="1:1" OutComeId="1311" variant="variant=sr:correct_score:max:6">4.83</Odds>
# 								<Odds OutCome="1:2" OutComeId="1312" variant="variant=sr:correct_score:max:6">8.4</Odds>
# 								<Odds OutCome="1:3" OutComeId="1313" variant="variant=sr:correct_score:max:6">19.69</Odds>
# 								<Odds OutCome="1:4" OutComeId="1314" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="1:5" OutComeId="1315" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="2:0" OutComeId="1316" variant="variant=sr:correct_score:max:6">12.52</Odds>
# 								<Odds OutCome="2:1" OutComeId="1317" variant="variant=sr:correct_score:max:6">10.12</Odds>
# 								<Odds OutCome="2:2" OutComeId="1318" variant="variant=sr:correct_score:max:6">14.33</Odds>
# 								<Odds OutCome="2:3" OutComeId="1319" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="2:4" OutComeId="1320" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="3:0" OutComeId="1321" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="3:1" OutComeId="1322" variant="variant=sr:correct_score:max:6">28.86</Odds>
# 								<Odds OutCome="3:2" OutComeId="1323" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="3:3" OutComeId="1324" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="4:0" OutComeId="1325" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="4:1" OutComeId="1326" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="4:2" OutComeId="1327" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="5:0" OutComeId="1328" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="5:1" OutComeId="1329" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="6:0" OutComeId="1330" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="other" OutComeId="1331" variant="variant=sr:correct_score:max:6">30</Odds>
# 								<Odds OutCome="0:0" OutComeId="1475" variant="variant=sr:correct_score:below:5-5">5.95</Odds>
# 								<Odds OutCome="1:0" OutComeId="1476" variant="variant=sr:correct_score:below:5-5">6.61</Odds>
# 								<Odds OutCome="2:0" OutComeId="1477" variant="variant=sr:correct_score:below:5-5">12.52</Odds>
# 								<Odds OutCome="3:0" OutComeId="1478" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="4:0" OutComeId="1479" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="5:0" OutComeId="1480" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="0:1" OutComeId="1481" variant="variant=sr:correct_score:below:5-5">5.5</Odds>
# 								<Odds OutCome="1:1" OutComeId="1482" variant="variant=sr:correct_score:below:5-5">4.83</Odds>
# 								<Odds OutCome="2:1" OutComeId="1483" variant="variant=sr:correct_score:below:5-5">10.12</Odds>
# 								<Odds OutCome="3:1" OutComeId="1484" variant="variant=sr:correct_score:below:5-5">28.86</Odds>
# 								<Odds OutCome="4:1" OutComeId="1485" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="5:1" OutComeId="1486" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="0:2" OutComeId="1487" variant="variant=sr:correct_score:below:5-5">8.61</Odds>
# 								<Odds OutCome="1:2" OutComeId="1488" variant="variant=sr:correct_score:below:5-5">8.4</Odds>
# 								<Odds OutCome="2:2" OutComeId="1489" variant="variant=sr:correct_score:below:5-5">14.33</Odds>
# 								<Odds OutCome="3:2" OutComeId="1490" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="4:2" OutComeId="1491" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="5:2" OutComeId="1492" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="0:3" OutComeId="1493" variant="variant=sr:correct_score:below:5-5">20.21</Odds>
# 								<Odds OutCome="1:3" OutComeId="1494" variant="variant=sr:correct_score:below:5-5">19.7</Odds>
# 								<Odds OutCome="2:3" OutComeId="1495" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="3:3" OutComeId="1496" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="4:3" OutComeId="1497" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="5:3" OutComeId="1498" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="0:4" OutComeId="1499" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="1:4" OutComeId="1500" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="2:4" OutComeId="1501" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="3:4" OutComeId="1502" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="4:4" OutComeId="1503" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="5:4" OutComeId="1504" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="0:5" OutComeId="1505" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="1:5" OutComeId="1506" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="2:5" OutComeId="1507" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="3:5" OutComeId="1508" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="4:5" OutComeId="1509" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 								<Odds OutCome="other" OutComeId="1510" variant="variant=sr:correct_score:below:5-5">30</Odds>
# 							</Bet>
# 							<Bet OddsType="540">
# 								<Odds OutCome="{$competitor1}/draw &amp; yes" OutComeId="1718">8.68</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; no" OutComeId="1719">1.8</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; yes" OutComeId="1720">8.51</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; no" OutComeId="1721">1.56</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; yes" OutComeId="1722">7.61</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; no" OutComeId="1723">1.56</Odds>
# 							</Bet>
# 							<Bet OddsType="541">
# 								<Odds OutCome="{$competitor1}/draw &amp; yes" OutComeId="1718">6.49</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; no" OutComeId="1719">1.94</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; yes" OutComeId="1720">6.5</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; no" OutComeId="1721">1.66</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; yes" OutComeId="1722">5.69</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; no" OutComeId="1723">1.67</Odds>
# 							</Bet>
# 							<Bet OddsType="542">
# 								<Odds OutCome="{$competitor1}/draw &amp; yes" OutComeId="1718">6.94</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; no" OutComeId="1719">1.59</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; yes" OutComeId="1720">14.58</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; no" OutComeId="1721">1.93</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; yes" OutComeId="1722">6.59</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; no" OutComeId="1723">1.46</Odds>
# 							</Bet>
# 							<Bet OddsType="543">
# 								<Odds OutCome="{$competitor1} &amp; yes" OutComeId="78">20.04</Odds>
# 								<Odds OutCome="{$competitor1} &amp; no" OutComeId="80">3.69</Odds>
# 								<Odds OutCome="draw &amp; yes" OutComeId="82">6.79</Odds>
# 								<Odds OutCome="draw &amp; no" OutComeId="84">3.01</Odds>
# 								<Odds OutCome="{$competitor2} &amp; yes" OutComeId="86">16.25</Odds>
# 								<Odds OutCome="{$competitor2} &amp; no" OutComeId="88">2.96</Odds>
# 							</Bet>
# 							<Bet OddsType="544">
# 								<Odds OutCome="{$competitor1} &amp; under {total}" OutComeId="794" SpecialBetValue="1.5">5.04</Odds>
# 								<Odds OutCome="{$competitor1} &amp; over {total}" OutComeId="796" SpecialBetValue="1.5">8.09</Odds>
# 								<Odds OutCome="draw &amp; under {total}" OutComeId="798" SpecialBetValue="1.5">3.03</Odds>
# 								<Odds OutCome="draw &amp; over {total}" OutComeId="800" SpecialBetValue="1.5">6.87</Odds>
# 								<Odds OutCome="{$competitor2} &amp; under {total}" OutComeId="802" SpecialBetValue="1.5">4.29</Odds>
# 								<Odds OutCome="{$competitor2} &amp; over {total}" OutComeId="804" SpecialBetValue="1.5">5.91</Odds>
# 							</Bet>
# 							<Bet OddsType="545">
# 								<Odds OutCome="{$competitor1}/draw &amp; yes" OutComeId="1718">5.43</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; no" OutComeId="1719">1.81</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; yes" OutComeId="1720">9.61</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; no" OutComeId="1721">1.8</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; yes" OutComeId="1722">5.13</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; no" OutComeId="1723">1.64</Odds>
# 							</Bet>
# 							<Bet OddsType="546">
# 								<Odds OutCome="{$competitor1}/draw &amp; yes" OutComeId="1718">2.92</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; no" OutComeId="1719">3.09</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; yes" OutComeId="1720">3.37</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; no" OutComeId="1721">2.17</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; yes" OutComeId="1722">2.62</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; no" OutComeId="1723">2.53</Odds>
# 							</Bet>
# 							<Bet OddsType="547">
# 								<Odds OutCome="{$competitor1}/draw &amp; under {total}" OutComeId="1724" SpecialBetValue="2.5">2.23</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; under {total}" OutComeId="1724" SpecialBetValue="3.5">1.85</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; under {total}" OutComeId="1724" SpecialBetValue="1.5">4.11</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; under {total}" OutComeId="1724" SpecialBetValue="4.5">1.61</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; under {total}" OutComeId="1725" SpecialBetValue="3.5">1.68</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; under {total}" OutComeId="1725" SpecialBetValue="2.5">2.56</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; under {total}" OutComeId="1725" SpecialBetValue="4.5">1.49</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; under {total}" OutComeId="1725" SpecialBetValue="1.5">3.94</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1726" SpecialBetValue="2.5">2.02</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1726" SpecialBetValue="3.5">1.63</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1726" SpecialBetValue="1.5">3.75</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1726" SpecialBetValue="4.5">1.41</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1727" SpecialBetValue="2.5">4.63</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1727" SpecialBetValue="3.5">7.87</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1727" SpecialBetValue="1.5">2.36</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1727" SpecialBetValue="4.5">22.38</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1728" SpecialBetValue="2.5">2.7</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1728" SpecialBetValue="3.5">6.06</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1728" SpecialBetValue="1.5">1.98</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1728" SpecialBetValue="4.5">11.26</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1729" SpecialBetValue="2.5">3.58</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1729" SpecialBetValue="3.5">6.19</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1729" SpecialBetValue="1.5">1.97</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1729" SpecialBetValue="4.5">16.04</Odds>
# 							</Bet>
# 							<Bet OddsType="548">
# 								<Odds OutCome="1-2" OutComeId="1730">1.82</Odds>
# 								<Odds OutCome="1-3" OutComeId="1731">1.36</Odds>
# 								<Odds OutCome="1-4" OutComeId="1732">1.19</Odds>
# 								<Odds OutCome="1-5" OutComeId="1733">1.13</Odds>
# 								<Odds OutCome="1-6" OutComeId="1734">1.11</Odds>
# 								<Odds OutCome="2-3" OutComeId="1735">1.93</Odds>
# 								<Odds OutCome="2-4" OutComeId="1736">1.58</Odds>
# 								<Odds OutCome="2-5" OutComeId="1737">1.47</Odds>
# 								<Odds OutCome="2-6" OutComeId="1738">1.43</Odds>
# 								<Odds OutCome="3-4" OutComeId="1739">2.81</Odds>
# 								<Odds OutCome="3-5" OutComeId="1740">2.44</Odds>
# 								<Odds OutCome="3-6" OutComeId="1741">2.33</Odds>
# 								<Odds OutCome="4-5" OutComeId="1742">5.09</Odds>
# 								<Odds OutCome="4-6" OutComeId="1743">4.57</Odds>
# 								<Odds OutCome="5-6" OutComeId="1744">11.79</Odds>
# 								<Odds OutCome="7+" OutComeId="1745">30</Odds>
# 								<Odds OutCome="no goal" OutComeId="1804">7.32</Odds>
# 							</Bet>
# 							<Bet OddsType="549">
# 								<Odds OutCome="1-2" OutComeId="1746">1.59</Odds>
# 								<Odds OutCome="1-3" OutComeId="1747">1.46</Odds>
# 								<Odds OutCome="2-3" OutComeId="1748">3.24</Odds>
# 								<Odds OutCome="4+" OutComeId="1749">30</Odds>
# 								<Odds OutCome="no goal" OutComeId="1805">2.33</Odds>
# 							</Bet>
# 							<Bet OddsType="550">
# 								<Odds OutCome="1-2" OutComeId="1746">1.53</Odds>
# 								<Odds OutCome="1-3" OutComeId="1747">1.36</Odds>
# 								<Odds OutCome="2-3" OutComeId="1748">2.64</Odds>
# 								<Odds OutCome="4+" OutComeId="1749">20.36</Odds>
# 								<Odds OutCome="no goal" OutComeId="1805">2.79</Odds>
# 							</Bet>
# 							<Bet OddsType="551">
# 								<Odds OutCome="1:0, 2:0 or 3:0" OutComeId="1750">5.02</Odds>
# 								<Odds OutCome="0:1, 0:2 or 0:3" OutComeId="1751">3.75</Odds>
# 								<Odds OutCome="4:0, 5:0 or 6:0" OutComeId="1752">30</Odds>
# 								<Odds OutCome="0:4, 0:5 or 0:6" OutComeId="1753">30</Odds>
# 								<Odds OutCome="2:1, 3:1 or 4:1" OutComeId="1754">9.13</Odds>
# 								<Odds OutCome="1:2, 1:3 or 1:4" OutComeId="1755">7</Odds>
# 								<Odds OutCome="3:2, 4:2, 4:3 or 5:1" OutComeId="1756">30</Odds>
# 								<Odds OutCome="2:3, 2:4, 3:4 or 1:5" OutComeId="1757">30</Odds>
# 								<Odds OutCome="other homewin" OutComeId="1758">30</Odds>
# 								<Odds OutCome="other awaywin" OutComeId="1759">30</Odds>
# 								<Odds OutCome="draw" OutComeId="1803">2.87</Odds>
# 							</Bet>
# 							<Bet OddsType="552">
# 								<Odds OutCome="1-2" OutComeId="1746">1.64</Odds>
# 								<Odds OutCome="1-3" OutComeId="1747">1.5</Odds>
# 								<Odds OutCome="2-3" OutComeId="1748">3.33</Odds>
# 								<Odds OutCome="4+" OutComeId="1749">30</Odds>
# 								<Odds OutCome="no goal" OutComeId="1805">2.24</Odds>
# 							</Bet>
# 							<Bet OddsType="553">
# 								<Odds OutCome="1-2" OutComeId="1746">1.51</Odds>
# 								<Odds OutCome="1-3" OutComeId="1747">1.34</Odds>
# 								<Odds OutCome="2-3" OutComeId="1748">2.54</Odds>
# 								<Odds OutCome="4+" OutComeId="1749">19.94</Odds>
# 								<Odds OutCome="no goal" OutComeId="1805">2.88</Odds>
# 							</Bet>
# 							<Bet OddsType="818">
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; under {total}" OutComeId="1836" SpecialBetValue="2.5">11.03</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; under {total}" OutComeId="1836" SpecialBetValue="3.5">7</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; under {total}" OutComeId="1836" SpecialBetValue="1.5">20.08</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; under {total}" OutComeId="1836" SpecialBetValue="4.5">6.08</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; under {total}" OutComeId="1837" SpecialBetValue="4.5">16.28</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; under {total}" OutComeId="1837" SpecialBetValue="2.5">23.31</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; under {total}" OutComeId="1837" SpecialBetValue="3.5">23.2</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; under {total}" OutComeId="1838" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; under {total}" OutComeId="1838" SpecialBetValue="3.5">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; under {total}" OutComeId="1839" SpecialBetValue="2.5">10.5</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; under {total}" OutComeId="1839" SpecialBetValue="3.5">7.77</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; under {total}" OutComeId="1839" SpecialBetValue="1.5">13.58</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; under {total}" OutComeId="1839" SpecialBetValue="4.5">7.29</Odds>
# 								<Odds OutCome="draw/draw &amp; under {total}" OutComeId="1840" SpecialBetValue="1.5">7.35</Odds>
# 								<Odds OutCome="draw/draw &amp; under {total}" OutComeId="1840" SpecialBetValue="2.5">4.61</Odds>
# 								<Odds OutCome="draw/draw &amp; under {total}" OutComeId="1840" SpecialBetValue="4.5">4.23</Odds>
# 								<Odds OutCome="draw/draw &amp; under {total}" OutComeId="1840" SpecialBetValue="3.5">4.59</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1841" SpecialBetValue="3.5">6.26</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1841" SpecialBetValue="2.5">8.48</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1841" SpecialBetValue="1.5">11.45</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1841" SpecialBetValue="4.5">5.82</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; under {total}" OutComeId="1842" SpecialBetValue="3.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; under {total}" OutComeId="1842" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; under {total}" OutComeId="1843" SpecialBetValue="4.5">15.72</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; under {total}" OutComeId="1843" SpecialBetValue="2.5">22.47</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; under {total}" OutComeId="1843" SpecialBetValue="3.5">22.37</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; under {total}" OutComeId="1844" SpecialBetValue="2.5">8.13</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; under {total}" OutComeId="1844" SpecialBetValue="3.5">5.09</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; under {total}" OutComeId="1844" SpecialBetValue="1.5">16.08</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; under {total}" OutComeId="1844" SpecialBetValue="4.5">4.32</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; over {total}" OutComeId="1845" SpecialBetValue="2.5">10.54</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; over {total}" OutComeId="1845" SpecialBetValue="3.5">23.47</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; over {total}" OutComeId="1845" SpecialBetValue="1.5">7.41</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; over {total}" OutComeId="1845" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1846" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1846" SpecialBetValue="1.5">15.65</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1846" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1846" SpecialBetValue="3.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1847" SpecialBetValue="1.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1847" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1847" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1847" SpecialBetValue="3.5">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; over {total}" OutComeId="1848" SpecialBetValue="2.5">20.08</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; over {total}" OutComeId="1848" SpecialBetValue="3.5">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; over {total}" OutComeId="1848" SpecialBetValue="1.5">13.98</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; over {total}" OutComeId="1848" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="draw/draw &amp; over {total}" OutComeId="1849" SpecialBetValue="1.5">9.51</Odds>
# 								<Odds OutCome="draw/draw &amp; over {total}" OutComeId="1849" SpecialBetValue="3.5">30</Odds>
# 								<Odds OutCome="draw/draw &amp; over {total}" OutComeId="1849" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="draw/draw &amp; over {total}" OutComeId="1849" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1850" SpecialBetValue="3.5">30</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1850" SpecialBetValue="2.5">15.31</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1850" SpecialBetValue="1.5">10.41</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1850" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; over {total}" OutComeId="1851" SpecialBetValue="1.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; over {total}" OutComeId="1851" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; over {total}" OutComeId="1851" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; over {total}" OutComeId="1851" SpecialBetValue="3.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; over {total}" OutComeId="1852" SpecialBetValue="4.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; over {total}" OutComeId="1852" SpecialBetValue="1.5">15.13</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; over {total}" OutComeId="1852" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; over {total}" OutComeId="1852" SpecialBetValue="3.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; over {total}" OutComeId="1853" SpecialBetValue="2.5">6.98</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; over {total}" OutComeId="1853" SpecialBetValue="3.5">14.38</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; over {total}" OutComeId="1853" SpecialBetValue="1.5">4.95</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; over {total}" OutComeId="1853" SpecialBetValue="4.5">29.65</Odds>
# 							</Bet>
# 							<Bet OddsType="819">
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; under {total}" OutComeId="1836" SpecialBetValue="2.5">6.33</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; under {total}" OutComeId="1836" SpecialBetValue="1.5">8.4</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; under {total}" OutComeId="1837" SpecialBetValue="2.5">17.55</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; under {total}" OutComeId="1837" SpecialBetValue="1.5">19.17</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; under {total}" OutComeId="1838" SpecialBetValue="1.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; under {total}" OutComeId="1838" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; under {total}" OutComeId="1839" SpecialBetValue="0.5">8.59</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; under {total}" OutComeId="1839" SpecialBetValue="1.5">8.66</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; under {total}" OutComeId="1839" SpecialBetValue="2.5">7</Odds>
# 								<Odds OutCome="draw/draw &amp; under {total}" OutComeId="1840" SpecialBetValue="0.5">5.26</Odds>
# 								<Odds OutCome="draw/draw &amp; under {total}" OutComeId="1840" SpecialBetValue="1.5">5.3</Odds>
# 								<Odds OutCome="draw/draw &amp; under {total}" OutComeId="1840" SpecialBetValue="2.5">4.25</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1841" SpecialBetValue="0.5">6.82</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1841" SpecialBetValue="2.5">5.56</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; under {total}" OutComeId="1841" SpecialBetValue="1.5">6.87</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; under {total}" OutComeId="1842" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; under {total}" OutComeId="1842" SpecialBetValue="1.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; under {total}" OutComeId="1843" SpecialBetValue="2.5">16.95</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; under {total}" OutComeId="1843" SpecialBetValue="1.5">18.54</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; under {total}" OutComeId="1844" SpecialBetValue="1.5">6.13</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; under {total}" OutComeId="1844" SpecialBetValue="2.5">4.49</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; over {total}" OutComeId="1845" SpecialBetValue="0.5">5.44</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; over {total}" OutComeId="1845" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; over {total}" OutComeId="1845" SpecialBetValue="1.5">15.08</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1846" SpecialBetValue="0.5">15.5</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1846" SpecialBetValue="1.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; over {total}" OutComeId="1846" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1847" SpecialBetValue="0.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1847" SpecialBetValue="1.5">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; over {total}" OutComeId="1847" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; over {total}" OutComeId="1848" SpecialBetValue="0.5">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; over {total}" OutComeId="1848" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; over {total}" OutComeId="1848" SpecialBetValue="1.5">30</Odds>
# 								<Odds OutCome="draw/draw &amp; over {total}" OutComeId="1849" SpecialBetValue="0.5">19.48</Odds>
# 								<Odds OutCome="draw/draw &amp; over {total}" OutComeId="1849" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="draw/draw &amp; over {total}" OutComeId="1849" SpecialBetValue="1.5">19.65</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1850" SpecialBetValue="0.5">26.83</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1850" SpecialBetValue="1.5">27.07</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; over {total}" OutComeId="1850" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; over {total}" OutComeId="1851" SpecialBetValue="0.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; over {total}" OutComeId="1851" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; over {total}" OutComeId="1851" SpecialBetValue="1.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; over {total}" OutComeId="1852" SpecialBetValue="0.5">14.98</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; over {total}" OutComeId="1852" SpecialBetValue="1.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; over {total}" OutComeId="1852" SpecialBetValue="2.5">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; over {total}" OutComeId="1853" SpecialBetValue="0.5">3.82</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; over {total}" OutComeId="1853" SpecialBetValue="1.5">9.72</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; over {total}" OutComeId="1853" SpecialBetValue="2.5">23.23</Odds>
# 							</Bet>
# 							<Bet OddsType="820">
# 								<Odds OutCome="draw/draw &amp; 0" OutComeId="1854">7.42</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; 1" OutComeId="1855">20.27</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; 1" OutComeId="1856">13.71</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; 1" OutComeId="1857">11.56</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; 1" OutComeId="1858">16.23</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; 2" OutComeId="1859">24.29</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; 2" OutComeId="1860">23.55</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; 2" OutComeId="1861">30</Odds>
# 								<Odds OutCome="draw/draw &amp; 2" OutComeId="1862">11.87</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; 2" OutComeId="1863">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; 2" OutComeId="1864">22.7</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; 2" OutComeId="1865">16.26</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; 3" OutComeId="1866">18.95</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; 3" OutComeId="1867">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; 3" OutComeId="1868">29.58</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; 3" OutComeId="1869">23.48</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; 3" OutComeId="1870">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; 3" OutComeId="1871">13.28</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; 4" OutComeId="1872">30</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; 4" OutComeId="1873">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; 4" OutComeId="1874">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; 4" OutComeId="1875">30</Odds>
# 								<Odds OutCome="draw/draw &amp; 4" OutComeId="1876">30</Odds>
# 								<Odds OutCome="draw/{$competitor2} &amp; 4" OutComeId="1877">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; 4" OutComeId="1878">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; 4" OutComeId="1879">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; 4" OutComeId="1880">27.84</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor1} &amp; 5+" OutComeId="1881">30</Odds>
# 								<Odds OutCome="{$competitor1}/draw &amp; 5+" OutComeId="1882">30</Odds>
# 								<Odds OutCome="{$competitor1}/{$competitor2} &amp; 5+" OutComeId="1883">30</Odds>
# 								<Odds OutCome="draw/{$competitor1} &amp; 5+" OutComeId="1884">30</Odds>
# 								<Odds OutCome="draw/draw &amp; 5+" OutComeId="1885">30</Odds>
# 								<Odds OutCome="draw/{$competitor2} y 5+" OutComeId="1886">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor1} &amp; 5+" OutComeId="1887">30</Odds>
# 								<Odds OutCome="{$competitor2}/draw &amp; 5+" OutComeId="1888">30</Odds>
# 								<Odds OutCome="{$competitor2}/{$competitor2} &amp; 5+" OutComeId="1889">30</Odds>
# 							</Bet>
# 							<Bet OddsType="854">
# 								<Odds OutCome="yes" OutComeId="74" SpecialBetValue="2.5">1.56</Odds>
# 								<Odds OutCome="no" OutComeId="76" SpecialBetValue="2.5">1.79</Odds>
# 							</Bet>
# 							<Bet OddsType="855">
# 								<Odds OutCome="yes" OutComeId="74" SpecialBetValue="2.5">1.19</Odds>
# 								<Odds OutCome="no" OutComeId="76" SpecialBetValue="2.5">2.76</Odds>
# 							</Bet>
# 							<Bet OddsType="856">
# 								<Odds OutCome="yes" OutComeId="74" SpecialBetValue="2.5">1.35</Odds>
# 								<Odds OutCome="no" OutComeId="76" SpecialBetValue="2.5">2.17</Odds>
# 							</Bet>
# 							<Bet OddsType="857">
# 								<Odds OutCome="yes" OutComeId="74" SpecialBetValue="2.5">1.36</Odds>
# 								<Odds OutCome="no" OutComeId="76" SpecialBetValue="2.5">2.41</Odds>
# 							</Bet>
# 							<Bet OddsType="858">
# 								<Odds OutCome="yes" OutComeId="74" SpecialBetValue="2.5">1.46</Odds>
# 								<Odds OutCome="no" OutComeId="76" SpecialBetValue="2.5">1.94</Odds>
# 							</Bet>
# 							<Bet OddsType="859">
# 								<Odds OutCome="yes" OutComeId="74" SpecialBetValue="2.5">1.12</Odds>
# 								<Odds OutCome="no" OutComeId="76" SpecialBetValue="2.5">3.22</Odds>
# 							</Bet>
# 							<Bet OddsType="860">
# 								<Odds OutCome="yes" OutComeId="74">1.36</Odds>
# 								<Odds OutCome="no" OutComeId="76">2.15</Odds>
# 							</Bet>
# 							<Bet OddsType="861">
# 								<Odds OutCome="yes" OutComeId="74">1.49</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.9</Odds>
# 							</Bet>
# 							<Bet OddsType="862">
# 								<Odds OutCome="yes" OutComeId="74">1.25</Odds>
# 								<Odds OutCome="no" OutComeId="76">2.49</Odds>
# 							</Bet>
# 							<Bet OddsType="863">
# 								<Odds OutCome="yes" OutComeId="74">1.34</Odds>
# 								<Odds OutCome="no" OutComeId="76">2.2</Odds>
# 							</Bet>
# 							<Bet OddsType="864">
# 								<Odds OutCome="yes" OutComeId="74">1.25</Odds>
# 								<Odds OutCome="no" OutComeId="76">2.87</Odds>
# 							</Bet>
# 							<Bet OddsType="865">
# 								<Odds OutCome="yes" OutComeId="74">1.32</Odds>
# 								<Odds OutCome="no" OutComeId="76">2.56</Odds>
# 							</Bet>
# 							<Bet OddsType="879">
# 								<Odds OutCome="yes" OutComeId="74">2.28</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.56</Odds>
# 							</Bet>
# 							<Bet OddsType="880">
# 								<Odds OutCome="yes" OutComeId="74">2.99</Odds>
# 								<Odds OutCome="no" OutComeId="76">1.34</Odds>
# 							</Bet>
# 							<Bet OddsType="881">
# 								<Odds OutCome="yes" OutComeId="74">1.37</Odds>
# 								<Odds OutCome="no" OutComeId="76">2.85</Odds>
# 							</Bet>
# 						</MatchOdds>
# 					</Match>
# 				</Tournament>
# 			</Category>
# 		</Sport>
# 		<Sport BetbalancerSportID="5">
# 			<Texts>
# 				<Text Language="BET">
# 					<Value>Tennis</Value>
# 				</Text>
# 				<Text Language="en">
# 					<Value>Tennis</Value>
# 				</Text>
# 				<Text Language="it">
# 					<Value>Tennis</Value>
# 				</Text>
# 			</Texts>
# 			<Category BetbalancerCategoryID="72">
# 				<Texts>
# 					<Text Language="BET">
# 						<Value>Challenger</Value>
# 					</Text>
# 					<Text Language="en">
# 						<Value>Challenger</Value>
# 					</Text>
# 					<Text Language="it">
# 						<Value>Challenge</Value>
# 					</Text>
# 				</Texts>
# 				<Tournament BetbalancerTournamentID="4209">
# 					<Texts>
# 						<Text Language="BET">
# 							<Value>ATP Challenger Quimper, France Men Singles</Value>
# 						</Text>
# 						<Text Language="en">
# 							<Value>ATP Challenger Quimper, France Men Singles</Value>
# 						</Text>
# 						<Text Language="it">
# 							<Value>ATP Challenger Quimper, Francia Uomini Singolare</Value>
# 						</Text>
# 					</Texts>
# 					<SuperTournament Name="ATP Challenger Quimper, France Men Singles" SuperID="4209"/>
# 					<Match BetbalancerMatchID="68308912">
# 						<Fixture>
# 							<Competitors>
# 								<Texts>
# 									<Text ID="679701"  SUPERID="679701" Type="1">
# 										<Text Language="BET">
# 											<Value>Gueymard Wayenburg, Sascha</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Gueymard Wayenburg, Sascha</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Gueymard Wayenburg, Sascha</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 								<Texts>
# 									<Text ID="66002"  SUPERID="66002" Type="2">
# 										<Text Language="BET">
# 											<Value>Lokoli, Laurent</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Lokoli, Laurent</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Lokoli, Laurent</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 							</Competitors>
# 							<DateInfo>
# 								<MatchDate Changed="1">2026-01-28T14:25:00.000Z</MatchDate>
# 							</DateInfo>
# 							<StatusInfo>
# 								<Off>0</Off>
# 							</StatusInfo>
# 							<NeutralGround>0</NeutralGround>
# 							<NumberOfSets>3</NumberOfSets>
# 						</Fixture>
# 						<Result>
# 							<ScoreInfo>
# 								<Score Type="FT">2:0</Score>
# 								<Score Type="Set1">6:1</Score>
# 								<Score Type="Set2">6:2</Score>
# 							</ScoreInfo>
# 						</Result>
# 						<BetResult>
# 							<W OddsType="186" OutComeId="4" OutCome="{$competitor1}"/>
# 							<W OddsType="188" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="1.5"/>
# 							<W OddsType="188" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-1.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="26.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="19.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="18.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="20.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="21.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="24.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="23.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="22.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="25.5"/>
# 							<W OddsType="189" OutComeId="13" OutCome="under {total}" SpecialBetValue="17.5"/>
# 							<W OddsType="190" OutComeId="13" OutCome="under {total}" SpecialBetValue="12.5"/>
# 							<W OddsType="191" OutComeId="13" OutCome="under {total}" SpecialBetValue="11.5"/>
# 							<W OddsType="192" OutComeId="74" OutCome="yes"/>
# 							<W OddsType="193" OutComeId="76" OutCome="no"/>
# 							<W OddsType="194" OutComeId="76" OutCome="no"/>
# 							<W OddsType="196" OutComeId="32" OutCome="2" variant="variant=sr:exact_sets:bestof:3"/>
# 							<W OddsType="198" OutComeId="70" OutCome="odd"/>
# 							<W OddsType="199" OutComeId="4" OutCome="2:0" variant="variant=sr:correct_score:bestof:3"/>
# 							<W OddsType="201" OutComeId="861" OutCome="{$competitor1}/{$competitor1}"/>
# 							<W OddsType="202" OutComeId="4" OutCome="{$competitor1}" variant="setnr=1"/>
# 							<W OddsType="202" OutComeId="4" OutCome="{$competitor1}" variant="setnr=2"/>
# 							<W OddsType="203" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-1.5" variant="setnr=1"/>
# 							<W OddsType="204" OutComeId="13" OutCome="under {total}" SpecialBetValue="9.5" variant="setnr=1"/>
# 							<W OddsType="207" OutComeId="866" OutCome="6:1" variant="setnr=1"/>
# 							<W OddsType="850" OutComeId="76" OutCome="no"/>
# 							<W OddsType="851" OutComeId="76" OutCome="no"/>
# 							<W OddsType="1055" OutComeId="975" OutCome="{$competitor1} &amp; under {total}" SpecialBetValue="22.5"/>
# 							<W OddsType="1055" OutComeId="975" OutCome="{$competitor1} &amp; under {total}" SpecialBetValue="21.5"/>
# 						</BetResult>
# 					</Match>
# 				</Tournament>
# 			</Category>
# 		</Sport>
# 		<Sport BetbalancerSportID="20">
# 			<Texts>
# 				<Text Language="BET">
# 					<Value>Table tennis</Value>
# 				</Text>
# 				<Text Language="en">
# 					<Value>Table Tennis</Value>
# 				</Text>
# 				<Text Language="it">
# 					<Value>Tennistavolo</Value>
# 				</Text>
# 			</Texts>
# 			<Category BetbalancerCategoryID="88">
# 				<Texts>
# 					<Text Language="BET">
# 						<Value>International</Value>
# 					</Text>
# 					<Text Language="en">
# 						<Value>International</Value>
# 					</Text>
# 					<Text Language="it">
# 						<Value>Internazionale</Value>
# 					</Text>
# 				</Texts>
# 				<Tournament BetbalancerTournamentID="32129">
# 					<Texts>
# 						<Text Language="BET">
# 							<Value>TT Cup</Value>
# 						</Text>
# 						<Text Language="en">
# 							<Value>TT Cup</Value>
# 						</Text>
# 						<Text Language="it">
# 							<Value>TT Cup</Value>
# 						</Text>
# 					</Texts>
# 					<SuperTournament Name="TT Cup" SuperID="32129"/>
# 					<Match BetbalancerMatchID="68339218">
# 						<Fixture>
# 							<Competitors>
# 								<Texts>
# 									<Text ID="1027101"  SUPERID="1027101" Type="1">
# 										<Text Language="BET">
# 											<Value>Benes, Radek</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Benes, Radek</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Benes, Radek</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 								<Texts>
# 									<Text ID="835420"  SUPERID="835420" Type="2">
# 										<Text Language="BET">
# 											<Value>Moravec, Borek</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Moravec, Borek</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Moravec, Borek</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 							</Competitors>
# 							<DateInfo>
# 								<MatchDate Changed="0">2026-01-28T15:10:00.000Z</MatchDate>
# 							</DateInfo>
# 							<StatusInfo>
# 								<Off>0</Off>
# 							</StatusInfo>
# 							<NeutralGround>0</NeutralGround>
# 							<NumberOfSets>5</NumberOfSets>
# 						</Fixture>
# 						<Result>
# 							<ScoreInfo>
# 								<Score Type="FT">3:2</Score>
# 								<Score Type="Set1">14:12</Score>
# 								<Score Type="Set2">6:11</Score>
# 								<Score Type="Set3">7:11</Score>
# 								<Score Type="Set4">11:7</Score>
# 								<Score Type="Set5">11:3</Score>
# 							</ScoreInfo>
# 						</Result>
# 						<BetResult>
# 							<W OddsType="186" OutComeId="4" OutCome="{$competitor1}"/>
# 							<W OddsType="199" OutComeId="10" OutCome="3:2" variant="variant=sr:correct_score:bestof:5"/>
# 							<W OddsType="237" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-7.5"/>
# 							<W OddsType="238" OutComeId="12" OutCome="over {total}" SpecialBetValue="73.5"/>
# 							<W OddsType="241" OutComeId="41" OutCome="5" variant="variant=sr:exact_games:bestof:5"/>
# 							<W OddsType="245" OutComeId="4" OutCome="{$competitor1}" variant="gamenr=1"/>
# 							<W OddsType="246" OutComeId="1715" OutCome="{$competitor2} ({+hcp})" SpecialBetValue="-2.5" variant="gamenr=1"/>
# 							<W OddsType="247" OutComeId="12" OutCome="over {total}" SpecialBetValue="18.5" variant="gamenr=1"/>
# 							<W OddsType="248" OutComeId="72" OutCome="even" variant="gamenr=1"/>
# 						</BetResult>
# 					</Match>
# 					<Match BetbalancerMatchID="68339220">
# 						<Fixture>
# 							<Competitors>
# 								<Texts>
# 									<Text ID="1026921"  SUPERID="1026921" Type="1">
# 										<Text Language="BET">
# 											<Value>Sikora, Filip</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Sikora, Filip</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Sikora, Filip</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 								<Texts>
# 									<Text ID="1026053"  SUPERID="1026053" Type="2">
# 										<Text Language="BET">
# 											<Value>Sarganek, David</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Sarganek, David</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Sarganek, David</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 							</Competitors>
# 							<DateInfo>
# 								<MatchDate Changed="0">2026-01-28T15:15:00.000Z</MatchDate>
# 							</DateInfo>
# 							<StatusInfo>
# 								<Off>0</Off>
# 							</StatusInfo>
# 							<NeutralGround>0</NeutralGround>
# 							<NumberOfSets>5</NumberOfSets>
# 						</Fixture>
# 						<Result>
# 							<ScoreInfo>
# 								<Score Type="FT">3:1</Score>
# 								<Score Type="Set1">11:8</Score>
# 								<Score Type="Set2">13:11</Score>
# 								<Score Type="Set3">7:11</Score>
# 								<Score Type="Set4">12:10</Score>
# 							</ScoreInfo>
# 						</Result>
# 						<BetResult>
# 							<W OddsType="186" OutComeId="4" OutCome="{$competitor1}"/>
# 							<W OddsType="199" OutComeId="9" OutCome="3:1" variant="variant=sr:correct_score:bestof:5"/>
# 							<W OddsType="237" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-1.5"/>
# 							<W OddsType="238" OutComeId="12" OutCome="over {total}" SpecialBetValue="75.5"/>
# 							<W OddsType="241" OutComeId="40" OutCome="4" variant="variant=sr:exact_games:bestof:5"/>
# 							<W OddsType="245" OutComeId="4" OutCome="{$competitor1}" variant="gamenr=1"/>
# 							<W OddsType="246" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-2.5" variant="gamenr=1"/>
# 							<W OddsType="247" OutComeId="12" OutCome="over {total}" SpecialBetValue="18.5" variant="gamenr=1"/>
# 							<W OddsType="248" OutComeId="70" OutCome="odd" variant="gamenr=1"/>
# 						</BetResult>
# 					</Match>
# 					<Match BetbalancerMatchID="68339226">
# 						<Fixture>
# 							<Competitors>
# 								<Texts>
# 									<Text ID="1026469"  SUPERID="1026469" Type="1">
# 										<Text Language="BET">
# 											<Value>Pribyl, Jan</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Pribyl, Jan</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Pribyl, Jan</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 								<Texts>
# 									<Text ID="835420"  SUPERID="835420" Type="2">
# 										<Text Language="BET">
# 											<Value>Moravec, Borek</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Moravec, Borek</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Moravec, Borek</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 							</Competitors>
# 							<DateInfo>
# 								<MatchDate Changed="0">2026-01-28T15:40:00.000Z</MatchDate>
# 							</DateInfo>
# 							<StatusInfo>
# 								<Off>0</Off>
# 							</StatusInfo>
# 							<NeutralGround>0</NeutralGround>
# 							<NumberOfSets>5</NumberOfSets>
# 						</Fixture>
# 						<MatchOdds>
# 							<Bet OddsType="186">
# 								<Odds OutCome="-1" OutComeId="4">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="199">
# 								<Odds OutCome="-1" OutComeId="8" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="9" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="10" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="11" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="12" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="13" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="237">
# 								<Odds OutCome="-1" OutComeId="1714" SpecialBetValue="-5.5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="1715" SpecialBetValue="-5.5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="238">
# 								<Odds OutCome="-1" OutComeId="12" SpecialBetValue="74.5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="12" SpecialBetValue="75.5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="13" SpecialBetValue="74.5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="13" SpecialBetValue="75.5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="241">
# 								<Odds OutCome="-1" OutComeId="39" variant="variant=sr:exact_games:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="40" variant="variant=sr:exact_games:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="41" variant="variant=sr:exact_games:bestof:5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="245">
# 								<Odds OutCome="-1" OutComeId="4" variant="gamenr=1">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="5" variant="gamenr=1">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="246">
# 								<Odds OutCome="-1" OutComeId="1714" SpecialBetValue="-2.5" variant="gamenr=1">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="1715" SpecialBetValue="-2.5" variant="gamenr=1">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="247">
# 								<Odds OutCome="-1" OutComeId="12" SpecialBetValue="18.5" variant="gamenr=1">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="13" SpecialBetValue="18.5" variant="gamenr=1">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="248">
# 								<Odds OutCome="-1" OutComeId="70" variant="gamenr=1">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="72" variant="gamenr=1">OFF</Odds>
# 							</Bet>
# 						</MatchOdds>
# 					</Match>
# 				</Tournament>
# 				<Tournament BetbalancerTournamentID="36377">
# 					<Texts>
# 						<Text Language="BET">
# 							<Value>TT Elite Series</Value>
# 						</Text>
# 						<Text Language="en">
# 							<Value>TT Elite Series</Value>
# 						</Text>
# 						<Text Language="it">
# 							<Value>TT Elite Series</Value>
# 						</Text>
# 					</Texts>
# 					<SuperTournament Name="TT Elite Series" SuperID="36377"/>
# 					<Match BetbalancerMatchID="68305978">
# 						<Fixture>
# 							<Competitors>
# 								<Texts>
# 									<Text ID="890721"  SUPERID="890721" Type="1">
# 										<Text Language="BET">
# 											<Value>Radlo, Szymon</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Radlo, Szymon</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Radlo, Szymon</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 								<Texts>
# 									<Text ID="915173"  SUPERID="915173" Type="2">
# 										<Text Language="BET">
# 											<Value>Zochniak, Jakub</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Zochniak, Jakub</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Zochniak, Jakub</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 							</Competitors>
# 							<DateInfo>
# 								<MatchDate Changed="0">2026-01-28T15:20:00.000Z</MatchDate>
# 							</DateInfo>
# 							<StatusInfo>
# 								<Off>0</Off>
# 							</StatusInfo>
# 							<NeutralGround>0</NeutralGround>
# 							<NumberOfSets>5</NumberOfSets>
# 						</Fixture>
# 						<Result>
# 							<ScoreInfo>
# 								<Score Type="FT">3:1</Score>
# 								<Score Type="Set1">9:11</Score>
# 								<Score Type="Set2">11:8</Score>
# 								<Score Type="Set3">11:7</Score>
# 								<Score Type="Set4">13:11</Score>
# 							</ScoreInfo>
# 						</Result>
# 						<BetResult>
# 							<W OddsType="186" OutComeId="4" OutCome="{$competitor1}"/>
# 							<W OddsType="199" OutComeId="9" OutCome="3:1" variant="variant=sr:correct_score:bestof:5"/>
# 							<W OddsType="237" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="3.5"/>
# 							<W OddsType="237" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="4.5"/>
# 							<W OddsType="238" OutComeId="12" OutCome="over {total}" SpecialBetValue="79.5"/>
# 							<W OddsType="238" OutComeId="12" OutCome="over {total}" SpecialBetValue="75.5"/>
# 							<W OddsType="241" OutComeId="40" OutCome="4" variant="variant=sr:exact_games:bestof:5"/>
# 							<W OddsType="245" OutComeId="5" OutCome="{$competitor2}" variant="gamenr=1"/>
# 							<W OddsType="246" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="2.5" variant="gamenr=1"/>
# 							<W OddsType="247" OutComeId="12" OutCome="over {total}" SpecialBetValue="18.5" variant="gamenr=1"/>
# 							<W OddsType="248" OutComeId="72" OutCome="even" variant="gamenr=1"/>
# 						</BetResult>
# 					</Match>
# 					<Match BetbalancerMatchID="68305980">
# 						<Fixture>
# 							<Competitors>
# 								<Texts>
# 									<Text ID="899759"  SUPERID="899759" Type="1">
# 										<Text Language="BET">
# 											<Value>Jarocki, Lukasz</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Jarocki, Lukasz</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Jarocki, Lukasz</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 								<Texts>
# 									<Text ID="926759"  SUPERID="926759" Type="2">
# 										<Text Language="BET">
# 											<Value>Wisniewski, Karol</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Wisniewski, Karol</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Wisniewski, Karol</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 							</Competitors>
# 							<DateInfo>
# 								<MatchDate Changed="0">2026-01-28T15:25:00.000Z</MatchDate>
# 							</DateInfo>
# 							<StatusInfo>
# 								<Off>0</Off>
# 							</StatusInfo>
# 							<NeutralGround>0</NeutralGround>
# 							<NumberOfSets>5</NumberOfSets>
# 						</Fixture>
# 						<Result>
# 							<ScoreInfo>
# 								<Score Type="FT">3:0</Score>
# 								<Score Type="Set1">11:4</Score>
# 								<Score Type="Set2">14:12</Score>
# 								<Score Type="Set3">11:4</Score>
# 							</ScoreInfo>
# 						</Result>
# 						<BetResult>
# 							<W OddsType="186" OutComeId="4" OutCome="{$competitor1}"/>
# 							<W OddsType="199" OutComeId="8" OutCome="3:0" variant="variant=sr:correct_score:bestof:5"/>
# 							<W OddsType="237" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="0.5"/>
# 							<W OddsType="237" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-1.5"/>
# 							<W OddsType="238" OutComeId="13" OutCome="under {total}" SpecialBetValue="74.5"/>
# 							<W OddsType="238" OutComeId="13" OutCome="under {total}" SpecialBetValue="76.5"/>
# 							<W OddsType="238" OutComeId="13" OutCome="under {total}" SpecialBetValue="75.5"/>
# 							<W OddsType="241" OutComeId="39" OutCome="3" variant="variant=sr:exact_games:bestof:5"/>
# 							<W OddsType="245" OutComeId="4" OutCome="{$competitor1}" variant="gamenr=1"/>
# 							<W OddsType="246" OutComeId="1714" OutCome="{$competitor1} ({+hcp})" SpecialBetValue="2.5" variant="gamenr=1"/>
# 							<W OddsType="246" OutComeId="1714" OutCome="{$competitor1} ({-hcp})" SpecialBetValue="-2.5" variant="gamenr=1"/>
# 							<W OddsType="247" OutComeId="13" OutCome="under {total}" SpecialBetValue="18.5" variant="gamenr=1"/>
# 							<W OddsType="248" OutComeId="70" OutCome="odd" variant="gamenr=1"/>
# 						</BetResult>
# 					</Match>
# 					<Match BetbalancerMatchID="68305986">
# 						<Fixture>
# 							<Competitors>
# 								<Texts>
# 									<Text ID="1117987"  SUPERID="1117987" Type="1">
# 										<Text Language="BET">
# 											<Value>Sulkowski, Bartek</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Sulkowski, Bartek</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Sulkowski, Bartek</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 								<Texts>
# 									<Text ID="903357"  SUPERID="903357" Type="2">
# 										<Text Language="BET">
# 											<Value>Krawczyk, Jakub</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Krawczyk, Jakub</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Krawczyk, Jakub</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 							</Competitors>
# 							<DateInfo>
# 								<MatchDate Changed="0">2026-01-28T15:40:00.000Z</MatchDate>
# 							</DateInfo>
# 							<StatusInfo>
# 								<Off>0</Off>
# 							</StatusInfo>
# 							<NeutralGround>0</NeutralGround>
# 							<NumberOfSets>5</NumberOfSets>
# 						</Fixture>
# 						<MatchOdds>
# 							<Bet OddsType="186">
# 								<Odds OutCome="-1" OutComeId="4">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="199">
# 								<Odds OutCome="-1" OutComeId="8" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="9" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="10" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="11" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="12" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="13" variant="variant=sr:correct_score:bestof:5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="237">
# 								<Odds OutCome="-1" OutComeId="1714" SpecialBetValue="4.5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="1715" SpecialBetValue="4.5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="238">
# 								<Odds OutCome="-1" OutComeId="12" SpecialBetValue="75.5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="13" SpecialBetValue="75.5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="241">
# 								<Odds OutCome="-1" OutComeId="39" variant="variant=sr:exact_games:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="40" variant="variant=sr:exact_games:bestof:5">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="41" variant="variant=sr:exact_games:bestof:5">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="245">
# 								<Odds OutCome="-1" OutComeId="4" variant="gamenr=1">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="5" variant="gamenr=1">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="246">
# 								<Odds OutCome="-1" OutComeId="1714" SpecialBetValue="2.5" variant="gamenr=1">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="1715" SpecialBetValue="2.5" variant="gamenr=1">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="247">
# 								<Odds OutCome="-1" OutComeId="12" SpecialBetValue="18.5" variant="gamenr=1">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="13" SpecialBetValue="18.5" variant="gamenr=1">OFF</Odds>
# 							</Bet>
# 							<Bet OddsType="248">
# 								<Odds OutCome="-1" OutComeId="70" variant="gamenr=1">OFF</Odds>
# 								<Odds OutCome="-1" OutComeId="72" variant="gamenr=1">OFF</Odds>
# 							</Bet>
# 						</MatchOdds>
# 					</Match>
# 					<Match BetbalancerMatchID="68306046">
# 						<Fixture>
# 							<Competitors>
# 								<Texts>
# 									<Text ID="977087"  SUPERID="977087" Type="1">
# 										<Text Language="BET">
# 											<Value>Kolodziej, Krystian</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Kolodziej, Krystian</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Kolodziej, Krystian</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 								<Texts>
# 									<Text ID="988913"  SUPERID="988913" Type="2">
# 										<Text Language="BET">
# 											<Value>Jendrzejewski, Patryk</Value>
# 										</Text>
# 										<Text Language="en">
# 											<Value>Jendrzejewski, Patryk</Value>
# 										</Text>
# 										<Text Language="it">
# 											<Value>Jendrzejewski, Patryk</Value>
# 										</Text>
# 									</Text>
# 								</Texts>
# 							</Competitors>
# 							<DateInfo>
# 								<MatchDate Changed="0">2026-01-28T18:00:00.000Z</MatchDate>
# 							</DateInfo>
# 							<StatusInfo>
# 								<Off>0</Off>
# 							</StatusInfo>
# 							<NeutralGround>0</NeutralGround>
# 							<NumberOfSets>5</NumberOfSets>
# 						</Fixture>
# 						<MatchOdds>
# 							<Bet OddsType="186">
# 								<Odds OutCome="{$competitor1}" OutComeId="4">1.2</Odds>
# 								<Odds OutCome="{$competitor2}" OutComeId="5">4</Odds>
# 							</Bet>
# 							<Bet OddsType="199">
# 								<Odds OutCome="3:0" OutComeId="8" variant="variant=sr:correct_score:bestof:5">2.65</Odds>
# 								<Odds OutCome="3:1" OutComeId="9" variant="variant=sr:correct_score:bestof:5">3.05</Odds>
# 								<Odds OutCome="3:2" OutComeId="10" variant="variant=sr:correct_score:bestof:5">4.9</Odds>
# 								<Odds OutCome="2:3" OutComeId="11" variant="variant=sr:correct_score:bestof:5">9.2</Odds>
# 								<Odds OutCome="1:3" OutComeId="12" variant="variant=sr:correct_score:bestof:5">12</Odds>
# 								<Odds OutCome="0:3" OutComeId="13" variant="variant=sr:correct_score:bestof:5">21</Odds>
# 							</Bet>
# 							<Bet OddsType="237">
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-8.5">1.69</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-8.5">1.79</Odds>
# 							</Bet>
# 							<Bet OddsType="238">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="71.5">1.74</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="71.5">1.74</Odds>
# 							</Bet>
# 							<Bet OddsType="241">
# 								<Odds OutCome="3" OutComeId="39" variant="variant=sr:exact_games:bestof:5">2.33</Odds>
# 								<Odds OutCome="4" OutComeId="40" variant="variant=sr:exact_games:bestof:5">2.43</Odds>
# 								<Odds OutCome="5" OutComeId="41" variant="variant=sr:exact_games:bestof:5">3.25</Odds>
# 							</Bet>
# 							<Bet OddsType="245">
# 								<Odds OutCome="{$competitor1}" OutComeId="4" variant="gamenr=1">1.3</Odds>
# 								<Odds OutCome="{$competitor2}" OutComeId="5" variant="gamenr=1">2.65</Odds>
# 							</Bet>
# 							<Bet OddsType="246">
# 								<Odds OutCome="{$competitor1} ({-hcp})" OutComeId="1714" SpecialBetValue="-2.5" variant="gamenr=1">1.71</Odds>
# 								<Odds OutCome="{$competitor2} ({+hcp})" OutComeId="1715" SpecialBetValue="-2.5" variant="gamenr=1">1.77</Odds>
# 							</Bet>
# 							<Bet OddsType="247">
# 								<Odds OutCome="over {total}" OutComeId="12" SpecialBetValue="18.5" variant="gamenr=1">1.83</Odds>
# 								<Odds OutCome="under {total}" OutComeId="13" SpecialBetValue="18.5" variant="gamenr=1">1.66</Odds>
# 							</Bet>
# 							<Bet OddsType="248">
# 								<Odds OutCome="odd" OutComeId="70" variant="gamenr=1">2.17</Odds>
# 								<Odds OutCome="even" OutComeId="72" variant="gamenr=1">1.45</Odds>
# 							</Bet>
# 						</MatchOdds>
# 					</Match>
# 				</Tournament>
# 			</Category>
# 		</Sport>
# 	</Sports>
# </BetbalancerBetData>