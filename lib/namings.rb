module Namings
    include MarketNames

    def market_namings
        # Use find_each to process in batches and avoid loading all records into memory
        PreMarket.find_each do |market|
            if market.name.nil?
                market.update(name: market_name(market.market_identifier.to_i))
            end
        end
    end
end