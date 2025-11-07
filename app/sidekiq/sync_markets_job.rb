class SyncMarketsJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform(*args)
    bet_balancer = BetBalancer.new

    Sport.each do |sport|
      markets_data = bet_balancer.get_matches(sport_id: sport.ext_sport_id)

      markets_data
        .xpath("//MatchOdds")
        .each do |market|
          market_id = market["OddsType"].to_i
          market_name = market.at_xpath("Text[@Language='en']/Value").content

          if Market.exists?(external_id: market_id, sport: sport)
            existing_market =
              Market.find_by(external_id: market_id, sport: sport)
            if existing_market.name != market_name
              existing_market.update(name: market_name)
            end
          else
            Market.create(
              ext_market_id: market_id,
              name: market_name,
              sport: sport,
              status: "active"
            )
          end
        end
    end
  end
end
