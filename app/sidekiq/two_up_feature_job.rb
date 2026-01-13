class TwoUpFeatureJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  SOCCER_EXT_SPORT_ID = "1"
  MARKET_1X2_EXT_MARKET_ID = "1"

  def perform(fixture_id, home_score, away_score)
    # Query for all bets associated with the fixture
    # Bets that are still active (not settled)
    # Bets for soccer with ext_sport_id = 1
    # Markets with 1X2 with ext_market_id = 1
    # Outcomes that are either Home Win or Away Win (ext_outcome_id = 1 or 2)
    
    # return if it a draw with outcome 
    return if home_score == away_score

    if home_score > away_score
      outcome_id = '1'
    else
      outcome_id = '3'
    end

    bets = Bet.where(fixture_id: fixture_id, bet_type: 'PreMatch')
            .where.not(status: 'Closed')
            .where(market_identifier: MARKET_1X2_EXT_MARKET_ID)
            .where(outcome_id: outcome_id)

    # update all these bets as won and settled
    meta_data = { settlement_reason: 'Two Up Feature Triggered', settled_at: Time.current, score: "#{home_score}-#{away_score}" }
    bets.update_all(result: 'Win', status: 'Closed', meta_data: meta_data)
  end
end
