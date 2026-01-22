class CashoutCalculator
  # Cashout margin - bookmaker takes 15% on cashout offers
  CASHOUT_MARGIN = 0.80

  def initialize(bet_slip)
    @bet_slip = bet_slip
    @bets = bet_slip.bets.includes(:fixture)
  end

  def call
    # Check if bet slip is eligible for cashout
    return unavailable('Bet slip already settled') unless @bet_slip.status == 'Active'
    return unavailable('No bets in this slip') if @bets.empty?

    # if any of the fixtures has been lost, return unavailable with 0 offer
    bet_statuses = @bets.pluck(:result)
    if bet_statuses.any? {|status| status&.downcase == 'loss'}
      return unavailable("Bet slip already lost")
    end

    # Fetch current odds for all bets
    current_odds_data = fetch_current_odds

    unless current_odds_data[:all_available]
      return unavailable(current_odds_data[:reason] || 'Not all markets available')
    end

    # Calculate cashout value
    cashout_value = calculate_cashout_value(current_odds_data[:odds])

    if cashout_value <= 0
      return unavailable('Cashout value too low')
    end

    {
      available: true,
      cashout_value: cashout_value.round(2).to_f,
      potential_win: @bet_slip.payout.to_f.round(2),
      stake: @bet_slip.stake.to_f.round(2),
      current_odds: current_odds_data[:odds].inject(:*).round(2).to_f
    }
  end

  private

  def unavailable(reason)
    {
      available: false,
      reason: reason,
      cashout_value: 0,
      potential_win: @bet_slip.payout.to_f.round(2),
      stake: @bet_slip.stake.to_f.round(2)
    }
  end

  def fetch_current_odds
    current_odds = []
    unavailable_reason = nil

    @bets.each do |bet|
      # Check if fixture is cancelled or postponed
      if bet.fixture && ['cancelled', 'postponed', 'abandoned'].include?(bet.fixture.status)
        unavailable_reason = 'One or more fixtures cancelled'
        break
      end

      # Check if the bet is closed and stored the slip odd
      if bet.status == 'Closed'
        current_odds << bet.odds.to_f
        next
      end

      # Find the market based on bet type
      market = if bet.bet_type == 'Live'
                 LiveMarket.find_by(
                   fixture_id: bet.fixture_id,
                   market_identifier: bet.market_identifier,
                   specifier: bet.specifier,
                   status: 'active'
                 )
               else
                 PreMarket.find_by(
                   fixture_id: bet.fixture_id,
                   market_identifier: bet.market_identifier,
                   specifier: bet.specifier
                 )
               end

      # Check if market exists and has odds
      if market.nil? || market.odds.blank?
        unavailable_reason = 'One of the markets no longer available'
        break
      end

      # Find the current odds for this specific outcome
      outcome_odds = market.odds.values.find { |v| v['outcome_id']&.to_i == bet.outcome.to_i }

      if outcome_odds.nil? || outcome_odds['odd'].to_f <= 0
        unavailable_reason = 'Odds no longer available'
        break
      end

      current_odds << outcome_odds['odd'].to_f
    end

    if unavailable_reason
      { all_available: false, reason: unavailable_reason, odds: [] }
    else
      { all_available: true, odds: current_odds }
    end
  end

  def calculate_cashout_value(current_odds)
    return 0 if current_odds.empty?

    # Calculate current accumulator odds (multiply all odds together)
    current_accumulator_odds = current_odds.inject(:*)

    # # Calculate potential return at current odds
    # current_potential_return = @bet_slip.stake * current_accumulator_odds

    # # Apply bookmaker margin to the cashout value
    # cashout_value = current_potential_return * CASHOUT_MARGIN

    # # Calculate the max payout with house margin
    # max_payout = @bet_slip.payout * CASHOUT_MARGIN

    # # Ensure cashout value is between stake and potential payout
    # # Don't offer less than stake (user is winning) or more than original payout
    # cashout_value = [[[@bet_slip.stake, cashout_value].max, max_payout].min, 0].max
    
    initial_accumulator_odds = @bet_slip.odds

    cashout_value = (@bet_slip.stake * (initial_accumulator_odds / current_accumulator_odds)) * CASHOUT_MARGIN || 0

    cashout_value
  end
end
