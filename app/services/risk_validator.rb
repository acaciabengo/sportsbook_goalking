class RiskValidator
  attr_reader :user, :stake, :bets_data, :error_message, :potential_win

  def initialize(user, stake, bets_data)
    @user = user
    @stake = stake
    @bets_data = bets_data
    @error_message = nil
    @potential_win = calculate_potential_win
  end

  def validate
    return false unless validate_stake_limit
    return false unless validate_max_win_per_bet
    return false unless validate_daily_win_limit
    # SGM already handled elsewhere
    # return false unless validate_sgm_restrictions
    true
  end

  private

  # Calculate user's tier in real-time from last 7 days
  def calculate_current_tier
    seven_days_ago = 7.days.ago

    total_stakes = @user.bet_slips
                        .where('created_at >= ?', seven_days_ago)
                        .sum(:stake)

    total_payouts = @user.bet_slips
                         .where('created_at >= ?', seven_days_ago)
                         .where(status: 'Closed', result: 'Win')
                         .sum(:payout)

    net_winnings = total_payouts - total_stakes
    RiskConfig.calculate_tier(net_winnings)
  end

  def validate_stake_limit
    tier = calculate_current_tier
    bet_type = determine_bet_type
    limit = RiskConfig::STAKE_LIMITS[tier][bet_type]

    

    if @stake > limit
      @error_message = "Stake exceeds your current limit of UGX #{limit}"
      log_rejection('stake_limit_exceeded', tier: tier, limit: limit, bet_type: bet_type)
      return false
    end
    true
  end

  def validate_max_win_per_bet
    if @potential_win > RiskConfig::MAX_WIN_PER_BET
      @error_message = "Maximum win per bet exceeded"
      log_rejection('max_win_per_bet_exceeded', potential_win: @potential_win)
      return false
    end
    true
  end

  def validate_daily_win_limit
    # Calculate today's total exposure from active bets
    today = Date.today
    todays_exposure = @user.bet_slips
                           .where('DATE(created_at) = ?', today)
                           .where(status: 'Active')
                           .sum(:payout)

    if todays_exposure >= RiskConfig::MAX_WIN_PER_PLAYER_PER_DAY
      @error_message = "Daily win limit reached"
      log_rejection('daily_win_limit_reached', todays_exposure: todays_exposure)
      return false
    end

    if (todays_exposure + @potential_win) > RiskConfig::MAX_WIN_PER_PLAYER_PER_DAY
      @error_message = "Bet would exceed daily win limit"
      log_rejection('daily_win_limit_would_exceed',
                   todays_exposure: todays_exposure,
                   potential_win: @potential_win)
      return false
    end

    true
  end

  def validate_sgm_restrictions
    same_game_fixtures = detect_same_game_bets
    return true if same_game_fixtures.empty?

    same_game_fixtures.each do |fixture_id, bets|
      # Check max legs
      if bets.count > RiskConfig::SGM_MAX_LEGS
        @error_message = "SGM cannot exceed #{RiskConfig::SGM_MAX_LEGS} legs"
        log_rejection('sgm_max_legs_exceeded', legs: bets.count)
        return false
      end

      # Check allowed markets
      bets.each do |bet|
        unless RiskConfig::SGM_ALLOWED_MARKETS.include?(bet[:market_identifier])
          @error_message = "SGM market not allowed"
          log_rejection('sgm_invalid_market', market: bet[:market_identifier])
          return false
        end

        # Check goal line restrictions (market 18 = over/under)
        if bet[:market_identifier] == '18' && bet[:specifier]
          goal_line = extract_goal_line(bet[:specifier])
          unless RiskConfig::SGM_ALLOWED_GOAL_LINES.include?(goal_line)
            @error_message = "SGM goal line not allowed (must be 1.5-4.5)"
            log_rejection('sgm_invalid_goal_line', goal_line: goal_line)
            return false
          end
        end
      end
    end

    true
  end

  def determine_bet_type
    same_game_fixtures = detect_same_game_bets
    return :sgm if same_game_fixtures.any?
    return :singles if @bets_data.count == 1
    :parlays
  end

  def detect_same_game_bets
    fixture_counts = @bets_data.map { |bet| bet[:fixture_id] }.tally
    same_game_fixture_ids = fixture_counts.select { |id, count| count > 1 }.keys

    same_game_fixtures = {}
    same_game_fixture_ids.each do |fixture_id|
      same_game_fixtures[fixture_id] = @bets_data.select { |bet| bet[:fixture_id] == fixture_id }
    end

    same_game_fixtures
  end

  def calculate_potential_win
    total_odds = @bets_data.map { |bet| bet[:odd].to_f }.inject(:*).round(2)
    @stake * total_odds
  end

  def extract_goal_line(specifier)
    # specifier format: "total=2.5" or similar
    specifier.to_s.split('=').last
  end

  def log_rejection(reason, metadata = {})
    # Only log if BetRejection model exists
    return unless defined?(BetRejection)

    BetRejection.create(
      user: @user,
      stake: @stake,
      potential_win: @potential_win,
      rejection_reason: reason,
      bet_type: determine_bet_type.to_s,
      bet_count: @bets_data.count,
      bet_data: @bets_data,
      metadata: metadata
    )
  rescue => e
    Rails.logger.error("Failed to log bet rejection: #{e.message}")
  end
end
