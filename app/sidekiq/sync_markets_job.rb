class SyncMarketsJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform(*args)
    bet_balancer = BetBalancer.new

    Sport.all.each do |sport|
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
            market.at_xpath("Texts/Text[@Language='en']/Value").content

          if Market.exists?(ext_market_id: market_id, sport_id: sport.id)
            existing_market =
              Market.find_by(ext_market_id: market_id, sport_id: sport.id)
            if existing_market.name != market_name
              unless existing_market.update(name: market_name)
                Rails.logger.error(
                  "Failed to update market: #{existing_market.errors.full_messages.join(", ")}"
                )
              end
            end
          else
            new_market =
              Market.create(
                ext_market_id: market_id,
                name: market_name,
                sport_id: sport.id
              )

            unless new_market.persisted?
              Rails.logger.error(
                "Failed to create market: #{new_market.errors.full_messages.join(", ")}"
              )
            end
          end
        end
    end
  end
end
