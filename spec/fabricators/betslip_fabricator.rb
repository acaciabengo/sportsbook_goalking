Fabricator(:bet_slip) do
  user
  bet_count { 1 }
  stake { 100.0 }
  win_amount { 0.0 }
  odds { 2.15 }
  payout { 215.0 }
  status { "Active" }
  paid { false }
  result { nil }
  reason { nil }
  bonus { 0.0 }
  tax { 0.0 }
  bet_slip_status { "Active" }
  bet_slip_result { nil }
end

# Pending bet slip (not settled yet)
Fabricator(:Active_bet_slip, from: :bet_slip) do
  status { "Active" }
  bet_slip_status { "Active" }
  result { nil }
  bet_slip_result { nil }
  paid { false }
end

# Active bet slip
Fabricator(:active_bet_slip, from: :bet_slip) do
  status { "active" }
  bet_slip_status { "active" }
  result { nil }
  bet_slip_result { nil }
  paid { false }
end

# Winning bet slip
Fabricator(:winning_bet_slip, from: :bet_slip) do
  status { "won" }
  bet_slip_status { "settled" }
  result { "win" }
  bet_slip_result { "win" }
  win_amount { 215.0 }
  paid { false }
end

# Paid winning bet slip
Fabricator(:paid_winning_bet_slip, from: :winning_bet_slip) { paid { true } }

# Losing bet slip
Fabricator(:losing_bet_slip, from: :bet_slip) do
  status { "lost" }
  bet_slip_status { "settled" }
  result { "loss" }
  bet_slip_result { "loss" }
  win_amount { 0.0 }
  paid { false }
end

# Void bet slip
Fabricator(:void_bet_slip, from: :bet_slip) do
  status { "void" }
  bet_slip_status { "settled" }
  result { "void" }
  bet_slip_result { "void" }
  win_amount { 100.0 }
  reason { "Match cancelled" }
  paid { false }
end

# Cancelled bet slip
Fabricator(:cancelled_bet_slip, from: :bet_slip) do
  status { "cancelled" }
  bet_slip_status { "cancelled" }
  result { "cancelled" }
  bet_slip_result { "cancelled" }
  win_amount { 100.0 }
  reason { "User cancelled" }
  paid { false }
end

# Single bet slip (1 selection)
Fabricator(:single_bet_slip, from: :bet_slip) do
  bet_count { 1 }
  odds { 2.15 }
  stake { 100.0 }
  payout { 215.0 }
end

# Double bet slip (2 selections)
Fabricator(:double_bet_slip, from: :bet_slip) do
  bet_count { 2 }
  odds { 4.62 }
  stake { 100.0 }
  payout { 462.0 }
end

# Treble bet slip (3 selections)
Fabricator(:treble_bet_slip, from: :bet_slip) do
  bet_count { 3 }
  odds { 9.93 }
  stake { 100.0 }
  payout { 993.0 }
end

# Multi-bet (accumulator with 5+ selections)
Fabricator(:multi_bet_slip, from: :bet_slip) do
  bet_count { 5 }
  odds { 32.50 }
  stake { 100.0 }
  payout { 3250.0 }
end

# Large accumulator (10+ selections)
Fabricator(:large_accumulator, from: :bet_slip) do
  bet_count { 10 }
  odds { 1024.0 }
  stake { 100.0 }
  payout { 102400.0 }
end

# Bet slip with bonus
Fabricator(:bet_slip_with_bonus, from: :bet_slip) do
  bet_count { 5 }
  odds { 32.50 }
  stake { 100.0 }
  bonus { 10.0 }
  payout { 3575.0 }
end

# Bet slip with tax
Fabricator(:bet_slip_with_tax, from: :bet_slip) do
  status { "won" }
  result { "win" }
  win_amount { 215.0 }
  tax { 32.25 }
  payout { 182.75 }
end

# High stake bet slip
Fabricator(:high_stake_bet_slip, from: :bet_slip) do
  stake { 10000.0 }
  odds { 2.15 }
  payout { 21500.0 }
end

# Low stake bet slip
Fabricator(:low_stake_bet_slip, from: :bet_slip) do
  stake { 10.0 }
  odds { 2.15 }
  payout { 21.50 }
end

# Bet slip with specific user
Fabricator(:bet_slip_with_user, from: :bet_slip) { user { Fabricate(:user) } }

# Bet slip with funded user
Fabricator(:bet_slip_with_funded_user, from: :bet_slip) do
  user { Fabricate(:user_with_balance, balance: 10000.0) }
end

# Bet slip with bets
Fabricator(:bet_slip_with_bets, from: :bet_slip) do
  bet_count { 3 }
  odds { 9.93 }
  after_create do |bet_slip|
    3.times { Fabricate(:bet, bet_slip: bet_slip, user: bet_slip.user) }
  end
end

# Bet slip with winning bets
Fabricator(:bet_slip_with_winning_bets, from: :winning_bet_slip) do
  bet_count { 3 }
  odds { 9.93 }
  after_create do |bet_slip|
    3.times do
      Fabricate(
        :winning_bet,
        bet_slip: bet_slip,
        user: bet_slip.user,
        status: "settled",
        result: "win"
      )
    end
  end
end

# Bet slip with losing bets
Fabricator(:bet_slip_with_losing_bets, from: :losing_bet_slip) do
  bet_count { 3 }
  after_create do |bet_slip|
    3.times do
      Fabricate(
        :losing_bet,
        bet_slip: bet_slip,
        user: bet_slip.user,
        status: "settled",
        result: "loss"
      )
    end
  end
end

# Bet slip with mixed bets (some won, some Active)
Fabricator(:bet_slip_with_mixed_bets, from: :bet_slip) do
  bet_count { 3 }
  status { "Active" }
  after_create do |bet_slip|
    Fabricate(:winning_bet, bet_slip: bet_slip, user: bet_slip.user)
    Fabricate(:losing_bet, bet_slip: bet_slip, user: bet_slip.user)
    Fabricate(:bet, bet_slip: bet_slip, user: bet_slip.user, status: "Active")
  end
end

# Bet slip with void bet
Fabricator(:bet_slip_with_void_bet, from: :void_bet_slip) do
  bet_count { 1 }
  after_create do |bet_slip|
    Fabricate(
      :void_bet,
      bet_slip: bet_slip,
      user: bet_slip.user,
      status: "settled",
      result: "void"
    )
  end
end

# Pre-match bet slip
Fabricator(:pre_match_bet_slip, from: :bet_slip) do
  after_create do |bet_slip|
    Fabricate(
      :pre_match_bet,
      bet_slip: bet_slip,
      user: bet_slip.user,
      product: "pre_match"
    )
  end
end

# Live bet slip
Fabricator(:live_bet_slip, from: :bet_slip) do
  after_create do |bet_slip|
    Fabricate(
      :live_bet,
      bet_slip: bet_slip,
      user: bet_slip.user,
      product: "live"
    )
  end
end

# Settled bet slip (generic)
Fabricator(:settled_bet_slip, from: :bet_slip) do
  bet_slip_status { "settled" }
  status { "settled" }
end

# Bet slip ready for payout
Fabricator(:bet_slip_ready_for_payout, from: :winning_bet_slip) do
  paid { false }
  win_amount { 215.0 }
  status { "won" }
  result { "win" }
end

# Recently created bet slip
Fabricator(:recent_bet_slip, from: :bet_slip) do
  created_at { 5.minutes.ago }
  status { "Active" }
end

# Old bet slip
Fabricator(:old_bet_slip, from: :bet_slip) do
  created_at { 30.days.ago }
  status { "settled" }
  result { "win" }
end

# Football bet slip
Fabricator(:football_bet_slip, from: :bet_slip) do
  bet_count { 3 }
  after_create do |bet_slip|
    3.times do
      fixture = Fabricate(:fixture, sport: "Football")
      Fabricate(
        :bet,
        bet_slip: bet_slip,
        user: bet_slip.user,
        fixture: fixture,
        sport: "Football"
      )
    end
  end
end

# Basketball bet slip
Fabricator(:basketball_bet_slip, from: :bet_slip) do
  bet_count { 2 }
  after_create do |bet_slip|
    2.times do
      fixture = Fabricate(:fixture, sport: "Basketball")
      Fabricate(
        :basketball_bet,
        bet_slip: bet_slip,
        user: bet_slip.user,
        fixture: fixture,
        sport: "Basketball"
      )
    end
  end
end

# Jackpot-style bet slip (many selections, low stake)
Fabricator(:jackpot_bet_slip, from: :bet_slip) do
  bet_count { 15 }
  stake { 10.0 }
  odds { 16384.0 }
  payout { 163840.0 }
end

# Bet slip with cancellation request
Fabricator(:bet_slip_with_cancel_request, from: :bet_slip) do
  after_create do |bet_slip|
    Fabricate(:bet_slip_cancel, bet_slip: bet_slip, status: "Active")
  end
end

# Partially settled bet slip (some bets settled, some Active)
Fabricator(:partially_settled_bet_slip, from: :bet_slip) do
  bet_count { 3 }
  status { "Active" }
  after_create do |bet_slip|
    Fabricate(:winning_bet, bet_slip: bet_slip, user: bet_slip.user)
    Fabricate(:losing_bet, bet_slip: bet_slip, user: bet_slip.user)
    Fabricate(:bet, bet_slip: bet_slip, user: bet_slip.user, status: "Active")
  end
end
