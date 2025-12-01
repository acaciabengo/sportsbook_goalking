class CloseSettledBetsJob
  include Sidekiq::Job
  sidekiq_options queue: "high"
  sidekiq_options retry: false

  VOID_FACTORS = %w[Cancelled Refund].freeze

  def perform(fixture_id, market_id, results, specifier)
    # find bets
    bets =
      Bet.joins(:fixture).where(
        fixtures: {
          id: fixture_id
        },
        bets: {
          market_identifier: market_id,
          status: "Active",
          specifier: specifier
        }
      )

    # Find the void factors present in results

    winning_bets = results.select { |k, v| v["status"] == "W" }.keys
    cancelled_bets = results.select { |k, v| v["status"] == "C" }.keys
    voided_bets = results.select { |k, v| v["void_factor"].to_f > 0 }.keys

    # Bulk update winning bets
    bets.where(outcome: winning_bets).update_all(
      result: "Win",
      status: "Closed"
    )

    # Bulk update void bets (cancelled + voided)
    void_outcomes = cancelled_bets + voided_bets
    bets.where(outcome: void_outcomes).update_all(
      result: "Void",
      status: "Closed"
    )

    # Bulk update losing bets (everything else)
    # Avoid loading all outcomes into memory by using SQL NOT IN instead of pluck
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

    # Update void_factor individually (if needed for specific outcomes)
    results.each do |outcome, data|
      if data["void_factor"].present?
        bets.where(outcome: outcome).update_all(
          void_factor: data["void_factor"].to_f
        )
      end
    end
  end
end
