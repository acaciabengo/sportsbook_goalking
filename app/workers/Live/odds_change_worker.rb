# check if desired provider exists else pick bet356 to avoid iterating over all providers

require "sidekiq"

class Live::OddsChangeWorker
  include Sidekiq::Worker
  sidekiq_options queue: "critical", retry: false

  def perform(message)
    # fetch events from the message
    events = message.fetch("Body", {}).fetch("Events", nil)
    return if events.nil?
    # change events into hash if single value
    events = [events] if events.is_a?(Hash)
    # iterate over events
    events.each do |event|
      event_id = event.fetch("FixtureId", nil)
      markets = event.fetch("Markets", nil)
      # convert to arry if single value
      markets = [markets] if markets.is_a?(Hash)
      # process odds change
      markets.each do |market|
        process_odds_change(event_id, market)
      end
    end
  end

  #   method to process the odd_change()
  def process_odds_change(event_id, market)
    market_status = {
      1 => "Active",
      2 => "Suspended",
      3 => "Settled",
    }

    # find the market
    fixture = Fixture.find_by(event_id: event_id)
    return if fixture.nil?

    # extract bets
    providers = market.fetch("Providers", nil)

    return if providers.nil?

    # iterate over providers
    providers.each do |provider|
      bets = provider.fetch("Bets", nil)
      next if bets.nil?

      #change into array if single value
      bets = [bets] if bets.is_a?(Hash)

      #group the bets by baseline
      bets = bets.group_by { |bet| bet.fetch("BaseLine", nil) }
      # iterate over bets
      bets.each do |key, values|
        odds = values.each_with_object({}) do |bet, result|
          result["outcome_#{bet["Name"]}"] = bet["Price"]
        end
        status = market_status[values.first["Status"]]
        market_entry = fixture.live_markets.find_or_initialize_by(market_identifier: market["Id"], specifier: key)
        market_entry.assign_attributes(status: status, odds: market_entry.odds.merge(odds))
        market_entry.save
      end
    end
  end
end
