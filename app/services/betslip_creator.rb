class BetslipCreator
  attr_reader :error_message, :bet_slip

  MAX_STAKE = 3_000_000
  MIN_STAKE = 1

  SAME_GAME_MAX_STAKE = 100_000
  SAME_GAME_MIN_STAKE = 2_000
  SAME_GAME_ACCEPETED_MARKETS = ["1", "10", "11", "29", "92"]
  SAME_GAME_DISCOUNT_FACTOR = 0.9

  def initialize(user, params)
    @user = user
    @bonus_flag = params[:bonus] == 'true' || params[:bonus] == true
    @stake = params[:stake]&.to_f
    @bets_data = params[:bets].is_a?(Array) ? params[:bets] : []
    @error_message = nil
    @bet_slip = nil
    @same_game_bets = []
    @same_game_flag = false
  end

  def call
    if @bonus_flag
      check_minimum_odds
      calculate_bonus_stake
      return false if @error_message
    end

    unless check_same_game_bets
      return false
    end

    if @same_game_flag
      return fail("Amount should be between #{SAME_GAME_MIN_STAKE} UGX and #{SAME_GAME_MAX_STAKE} UGX") unless valid_same_game_stake_range?
    end

    return fail("Amount should be between #{MIN_STAKE} UGX and #{MAX_STAKE} UGX") unless valid_stake_range?
    return fail("Insufficient balance") unless valid_balance?

    @bet_slip = @user.bet_slips.build(stake: @stake)
    
    pre_markets_data, live_markets_data = load_odds_data
    bets_arr = build_bets_array(pre_markets_data, live_markets_data)
    
    return false if @error_message

    ActiveRecord::Base.transaction do
      update_user_balance
      create_transaction_record
      finalize_betslip(bets_arr)
    end

    true
  rescue StandardError => e
    @error_message = e.message
    false
  end

  private

  def fail(message)
    @error_message = message
    false
  end

  def calculate_bonus_stake
    @user_bonuses = @user.user_bonuses.where('expires_at > ? AND status = ?', Time.now, 'Active')
    redeemable_bonus = @user_bonuses.sum(:amount)
    @stake = redeemable_bonus

    if redeemable_bonus < 1
      @error_message = "Insufficient bonus to place bet"
    end
  end

  def valid_stake_range?
    @stake >= MIN_STAKE && @stake <= MAX_STAKE
  end

  def valid_same_game_stake_range?
    @stake >= SAME_GAME_MIN_STAKE && @stake <= SAME_GAME_MAX_STAKE
  end

  def valid_balance?
    @bonus_flag || @stake <= @user.balance
  end

  def update_user_balance
    @previous_balance = @user.balance
    
    if @bonus_flag && @user_bonuses.present?
      @user_bonuses.update_all(status: 'Redeemed')
      @balance_after = @user.balance
    else
      @balance_after = @user.balance - @stake
      @user.update!(balance: @balance_after)
    end
  end

  def create_transaction_record
    @user.transactions.create!(
      balance_before: @previous_balance,
      balance_after: @balance_after,
      phone_number: @user.phone_number,
      status: 'SUCCESS',
      currency: 'UGX',
      amount: @stake,
      category: 'Bet Stake'
    )
  end

  def finalize_betslip(bets_arr)
    odds_arr = bets_arr.map { |x| x[:odds].to_f }
    total_odds = odds_arr.empty? ? 0.0 : odds_arr.inject(:*).round(2)
    win_amount = (@stake * total_odds).round(2)

    slip_bonus = SlipBonus.where('min_accumulator <= ? AND max_accumulator >= ?', bets_arr.count, bets_arr.count).where(status: 'Active')&.last
    if slip_bonus
      multiplier = slip_bonus.multiplier
      bonus_win = (win_amount * (multiplier.to_f / 100)).round(2)
    else
      bonus_win = 0.0
    end

    payout = (bonus_win + win_amount).round(2)
    tax = (bonus_win + win_amount) * BetSlip::TAX_RATE

    if @bonus_flag
      payout = win_amount.round(2) - (@stake).round(2)
      tax = payout * BetSlip::TAX_RATE
    end

    @bet_slip.assign_attributes(
      bet_count: bets_arr.count,
      stake: @stake,
      odds: total_odds,
      status: 'Active',
      win_amount: win_amount,
      bonus: bonus_win,
      tax: tax,
      payout: payout
    )
    @bet_slip.save!

    Bet.create!(bets_arr) if bets_arr.any?
  end

  def build_bets_array(pre_markets_data, live_markets_data)
    bets_arr = []

    # # Apply same game discount ONCE before processing
    # if @same_game_flag
    #   same_game_fixture_ids = @same_game_bets.map { |b| b[:fixture_id] }
    #   @bets_data.each do |bet|
    #     if same_game_fixture_ids.include?(bet[:fixture_id])
    #       original_odd = bet[:odd].to_f
    #       adjusted_odd = (original_odd * SAME_GAME_DISCOUNT_FACTOR).round(2)
    #       bet[:adjusted_odd] = adjusted_odd  # Store in new key
    #     end
    #   end
    # end

    @bets_data.each do |bet_data|
      fixture_id = bet_data[:fixture_id]&.to_i
      market_identifier = bet_data[:market_identifier]&.to_s
      specifier = bet_data[:specifier].presence
      outcome_id = bet_data[:outcome_id]&.to_i
      bet_type = bet_data[:bet_type]
      outcome_desc = bet_data[:outcome]&.to_s

      if bet_type == 'PreMatch'
        odds = pre_markets_data.dig(fixture_id, market_identifier, specifier) || {}
      else
        odds = live_markets_data.dig(fixture_id, market_identifier, specifier) || {}
      end

      odd_entry = odds.values.find { |v| v["outcome_id"]&.to_i == outcome_id&.to_i }
      current_odds = odd_entry.nil? ? nil : odd_entry["odd"]&.to_f

      if current_odds.nil? || current_odds == 0.0
        @error_message = "One of the bets has changed odds or is no longer available. Please review your bet and try again."
        return []
      end

      # Use adjusted odds if available for same game bets
      # final_odds = bet_data[:adjusted_odd] || current_odds
      
      final_odds = bet_data[:odd]&.to_f&.round(2)


      bets_arr << {
        user_id: @user.id,
        bet_slip: @bet_slip,
        fixture_id: fixture_id,
        market_identifier: market_identifier,
        odds: final_odds,
        outcome_desc: outcome_desc,
        outcome: outcome_id,
        specifier: specifier,
        status: 'Active',
        bet_type: bet_type
      }
    end

    # if there are same game bets, adjust their odds
    # recalculate the odds for same game bets at 90% of original odds
    if @same_game_bets.any?
      same_game_fixtures = @same_game_bets.map { |bet| bet[:fixture_id] }.uniq

      bets_arr.select { |bet| same_game_fixtures.include?(bet[:fixture_id]) }.each do |bet|
        original_odd = bet[:odds].to_f
        adjusted_odd = (original_odd * SAME_GAME_DISCOUNT_FACTOR).round(2)
        bet[:odds] = adjusted_odd
      end
    end
  
    bets_arr
  end

  def load_odds_data
    pre_match_criteria = []
    live_match_criteria = []

    @bets_data.each do |bet|
      criteria = {
        fixture_id: bet[:fixture_id],
        market_identifier: bet[:market_identifier].to_s,
        specifier: bet[:specifier]
      }
      
      if bet[:bet_type] == 'PreMatch'
        pre_match_criteria << criteria
      else
        live_match_criteria << criteria
      end
    end

    pre_markets = fetch_markets_safely(PreMarket, pre_match_criteria)
    live_markets = fetch_markets_safely(LiveMarket, live_match_criteria)

    pre_markets_data = {}
    live_markets_data = {}

    pre_markets.each do |market|
      pre_markets_data[market.fixture_id] ||= {}
      pre_markets_data[market.fixture_id][market.market_identifier] ||= {}
      pre_markets_data[market.fixture_id][market.market_identifier][market.specifier] = market.odds
    end

    live_markets.each do |market|
      live_markets_data[market.fixture_id] ||= {}
      live_markets_data[market.fixture_id][market.market_identifier] ||= {}
      live_markets_data[market.fixture_id][market.market_identifier][market.specifier] = market.odds
    end

    [pre_markets_data, live_markets_data]
  end

  def fetch_markets_safely(model_class, criteria_list)
    return [] if criteria_list.empty?

    fixture_ids = criteria_list.map { |c| c[:fixture_id] }.uniq
    candidates = model_class.where(fixture_id: fixture_ids)

    candidates.select do |market|
      criteria_list.any? do |c|
        market.fixture_id == c[:fixture_id].to_i &&
        market.market_identifier.to_s == c[:market_identifier].to_s &&
        market.specifier == c[:specifier]
      end
    end
  end

  def check_minimum_odds
    # if any of the bets odds is less than 1.5, set error message
    odds_arr = @bets_data.map { |bet| bet[:odd].to_f }
    if odds_arr.any? { |odd| odd < 1.5 }
      @error_message = "All bets must have minimum odds of 1.5 to use bonus stake."
    end
  end

  def check_same_game_bets
    return true if !@bets_data.is_a?(Array) || @bets_data.empty?

    fixture_counts = @bets_data.map { |bet| bet[:fixture_id] }.tally

    # return true if all counts are 1 (no same game bets)
    if fixture_counts.values.all? { |count| count == 1 }
      return true
    end

    @same_game_flag = true

    # find the fixtures with more than 1 bet
    same_game_fixtures = fixture_counts.select { |fixture_id, count| count > 1 }.keys
    same_game_bets = @bets_data.select { |bet| same_game_fixtures.include?(bet[:fixture_id]) }

    same_game_markets = same_game_bets.map { |bet| bet[:market_identifier].to_s }.uniq

    # if any of the markets is not in the accepted markets, set error message
    unless same_game_markets.all? { |market| SAME_GAME_ACCEPETED_MARKETS.include?(market) }
      @error_message = "Same game bets are only allowed for specific markets."
      return false
    end

    @same_game_bets = same_game_bets

    # # recalculate the odds for same game bets at 90% of original odds
    # @bets_data.each.select { |bet| same_game_fixtures.include?(bet[:fixture_id]) }.each do |bet|
    #   original_odd = bet[:odds].to_f
    #   adjusted_odd = (original_odd * SAME_GAME_DISCOUNT_FACTOR).round(2)
    #   bet[:odds] = adjusted_odd
    # end

    true
  end
end
