# select providers to work with to avoid unecessary entries in the database
# call the settle bets worker at the end of every market

require "sidekiq"
require "json"

class Live::BetSettlementWorker
  include Sidekiq::Worker
  sidekiq_options queue: "high", retry: false

  def perform(message)
    events = message.fetch("Body", {}).fetch("Events", nil)
    return if events.nil?

    events = [events] if events.is_a?(Hash)

    events.each do |event|
      event_id = event.fetch("FixtureId", nil)
      next if event_id.nil?

      fixture = Fixture.find_by(event_id: event_id)
      next if fixture.nil?

      fixture.update(status: "ended")

      markets = event.fetch("Markets", nil)
      if markets
        markets = [markets] if markets.is_a?(Hash)
        markets.each do |market|
          settle_markets(fixture, market)
        end
      end
    end
  end

  #   method to settle fixtures
  def settle_markets(fixture, market)
    settlement_status = {
      -1 => "Cancelled",
      1 => "Loser",
      2 => "Winner",
      3 => "Refund",
      4 => "HalfLost",
      5 => "HalfWon",

    }

    # check if there are providers
    providers = market.fetch("Providers", nil)
    return if providers.nil?

    providers.each do |provider|
      # iterate over providers
      bets = provider.fetch("Bets", nil)
      next if bets.nil?

      bets_with_baseline = bets.group_by { |bet| bet.fetch("BaseLine", nil) }
      bets_with_baseline.each do |baseline, settlements|
        specifier = baseline
        settlement = settlements.each_with_object({}) do |bet, result|
          result["Name"] = settlement_status[result["Settlement"]]
        end

        market_entry = fixture.live_markets.find_or_initialize_by(market_identifier: market["Id"], specifier: specifier)
        market_entry.assign_attributes(status: "Settled", results: settlement)
        market_entry.save
      end

      #   settle bets without baseline
      bets_without_baseline = bets - bets_with_baseline

      bets_without_baseline.each do |bet|
        settlement = settlement_status[bet["Settlement"]]
        market_entry = fixture.live_markets.find_or_initialize_by(market_identifier: market["Id"])
        market_entry.assign_attributes(status: "Settled", results: settlement)
        market_entry.save
      end
    end
  end

  def settle_bets(fixture_id, product, market_id, outcome, specifier = nil)
    #call worker to settle these bets
    CloseSettledBetsWorker.perform_async(fixture_id, product, market_id, outcome, specifier)
  end
end
