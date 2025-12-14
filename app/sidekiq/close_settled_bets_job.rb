class CloseSettledBetsJob
  include Sidekiq::Job
  sidekiq_options queue: "high"
  sidekiq_options retry: false

  VOID_FACTORS = %w[Cancelled Refund].freeze

  def perform(fixture_id, market_id, bet_type)

    # find the market
    if bet_type == 'PreMatch'
      market = PreMarket.find_by(id: market_id, fixture_id: fixture_id)
    else
      market = LiveMarket.find_by(id: market_id, fixture_id: fixture_id)
    end

    results = market&.results || {}

    if results.empty?
      Rails.logger.warn("No results found for market #{market_id} on fixture #{fixture_id}. Skipping bet settlement.")
      return
    end


    # find bets
    bets =
      Bet.joins(:fixture).where(
        fixtures: {
          id: fixture_id
        },
        bets: {
          market_identifier: market.market_identifier,
          status: "Active",
          specifier: market.specifier,
          bet_type: bet_type
        }
      )

    return if bets.empty?

        # Categorize outcomes - void takes precedence
    cancelled_bets = results.select { |k, v| v["status"] == "C" }.map { |_k, v| v["outcome_id"].to_s }
    voided_bets = results.select { |k, v| v["void_factor"].to_f > 0 }.map { |_k, v| v["outcome_id"].to_s }
    void_outcomes = (cancelled_bets + voided_bets).uniq
    
    # Winning bets (only if not void)
    winning_bets = results.select { |k, v| v["status"] == "W" && !void_outcomes.include?(k) }.map { |_k, v| v["outcome_id"].to_s }

    # Bulk update void bets first (cancelled + voided) with void_factor
    if void_outcomes.any?
      void_outcomes.each do |outcome|
        void_factor_value = results[outcome]["void_factor"].to_f
        bets.where(outcome: outcome).update_all(
          result: "Void",
          status: "Closed",
          void_factor: void_factor_value
        )
      end
    end

    # Bulk update winning bets
    if winning_bets.any?
      bets.where(outcome: winning_bets).update_all(
        result: "Win",
        status: "Closed"
      )
    end

    # Bulk update losing bets (everything else)
    all_processed_outcomes = winning_bets + void_outcomes
    if all_processed_outcomes.any?
      bets.where.not(outcome: all_processed_outcomes).update_all(
        result: "Loss",
        status: "Closed"
      )
    else
      # If no winning/void bets, all remaining are losing
      bets.update_all(
        result: "Loss",
        status: "Closed"
      )
    end
  end
end
