class SyncMarketsJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform(*args)
    bet_balancer = BetBalancer.new

    # Use find_each to process in batches and avoid loading all records into memory
    Sport.find_each do |sport|
      status, markets_data =
        bet_balancer.get_markets(sport_id: sport.ext_sport_id)
      if status != 200
        Rails.logger.error("Failed to fetch markets data: HTTP #{status}")
        next
      end

      markets_data
        .xpath("//MatchOdds/Bet")
        .each do |market|
          market_id = market["OddsType"].to_i
          market_name =
            market.at_xpath("Texts/Text[@Language='en']/Value")&.content

          next unless market_name.present? && market_id > 0

          market_record = Market.find_or_initialize_by(
            ext_market_id: market_id,
            sport_id: sport.id
          )

          if market_record.new_record? || market_record.name != market_name
            market_record.name = market_name

            unless market_record.save
              Rails.logger.error(
                "Failed to save market #{market_id}: #{market_record.errors.full_messages.join(", ")}"
              )
            end
          end
        end
      
      # Clear Nokogiri document from memory after processing each sport
      markets_data = nil
      GC.start if (sport.id % 10).zero? # Periodic GC hint every 10 sports
    end
  end
end
