Fabricator(:bet) do
  user
  fixture
  bet_slip
  market_identifier { "10" }
  specifier { nil }
  outcome { "1" }
  outcome_desc { "Home Win" }
  odds { 2.15 }
  status { "active" }
  product { "pre_match" }
  result { nil }
  reason { nil }
  void_factor { nil }
  sport { "Football" }
  bet_type { "PreMatch" }
end

Fabricator(:winning_bet, from: :bet) do
  result { "win" }
  status { "settled" }
end

Fabricator(:losing_bet, from: :bet) do
  result { "loss" }
  status { "settled" }
end

Fabricator(:void_bet, from: :bet) do
  result { "void" }
  status { "settled" }
  void_factor { 1.0 }
  reason { "Match cancelled" }
end

Fabricator(:partial_void_bet, from: :bet) do
  result { "void" }
  status { "settled" }
  void_factor { 0.5 }
  reason { "Partial refund" }
end

Fabricator(:pending_bet, from: :bet) do
  status { "pending" }
  result { nil }
end

Fabricator(:cancelled_bet, from: :bet) do
  status { "cancelled" }
  result { "cancelled" }
  reason { "User cancelled" }
end

# For Over/Under bets
Fabricator(:over_bet, from: :bet) do
  market_identifier { "18" }
  specifier { "total=2.5" }
  outcome { "Over" }
  outcome_desc { "Over 2.5" }
  odds { 1.85 }
end

Fabricator(:under_bet, from: :bet) do
  market_identifier { "18" }
  specifier { "total=2.5" }
  outcome { "Under" }
  outcome_desc { "Under 2.5" }
  odds { 1.95 }
end

# For 1X2 bets
Fabricator(:home_win_bet, from: :bet) do
  market_identifier { "10" }
  outcome { "1" }
  outcome_desc { "Home Win" }
  odds { 2.15 }
end

Fabricator(:draw_bet, from: :bet) do
  market_identifier { "10" }
  outcome { "X" }
  outcome_desc { "Draw" }
  odds { 3.20 }
end

Fabricator(:away_win_bet, from: :bet) do
  market_identifier { "10" }
  outcome { "2" }
  outcome_desc { "Away Win" }
  odds { 3.50 }
end

# For Both Teams to Score
Fabricator(:btts_yes_bet, from: :bet) do
  market_identifier { "29" }
  outcome { "Yes" }
  outcome_desc { "Both Teams to Score - Yes" }
  odds { 1.75 }
end

Fabricator(:btts_no_bet, from: :bet) do
  market_identifier { "29" }
  outcome { "No" }
  outcome_desc { "Both Teams to Score - No" }
  odds { 2.05 }
end

# For Double Chance
Fabricator(:double_chance_1x_bet, from: :bet) do
  market_identifier { "10" }
  outcome { "1X" }
  outcome_desc { "Home or Draw" }
  odds { 1.35 }
end

# For Correct Score
Fabricator(:correct_score_bet, from: :bet) do
  market_identifier { "14" }
  outcome { "1:0" }
  outcome_desc { "Correct Score 1:0" }
  odds { 8.50 }
end

# Live betting
Fabricator(:live_bet, from: :bet) do
  product { "live" }
  status { "active" }
end

# Pre-match betting
Fabricator(:pre_match_bet, from: :bet) do
  product { "pre_match" }
  status { "active" }
end

# With specific bet slip
Fabricator(:bet_with_slip, from: :bet) { bet_slip { Fabricate(:bet_slip) } }

# With specific user
Fabricator(:bet_with_user, from: :bet) { user { Fabricate.build(:user).save } }

# With specific fixture
Fabricator(:bet_with_fixture, from: :bet) do
  fixture do
    Fabricate(
      :fixture,
      home_team: "Manchester United",
      away_team: "Liverpool",
      status: "not_started"
    )
  end
end

# Basketball bets
Fabricator(:basketball_bet, from: :bet) do
  sport { "Basketball" }
  fixture do
    Fabricate(
      :fixture,
      home_team: "Lakers",
      away_team: "Celtics",
      sport: Fabricate(:basketball)
    )
  end
end

Fabricator(:basketball_money_line_bet, from: :basketball_bet) do
  market_identifier { "219" }
  outcome { "1" }
  outcome_desc { "Home Win" }
  odds { 1.85 }
end

# Tennis bets
Fabricator(:tennis_bet, from: :bet) do
  sport { "Tennis" }
  fixture do
    Fabricate(
      :fixture,
      home_team: "Federer",
      away_team: "Nadal",
      sport: Fabricate(:tennis)
    )
  end
end

# Multiple bets for same slip
Fabricator(:multiple_bets_slip, from: :bet_slip) do
  after_create { |slip| 3.times { Fabricate(:bet, bet_slip: slip) } }
end

# Settled bets with different outcomes
Fabricator(:settled_winning_bet, from: :bet) do
  status { "settled" }
  result { "win" }
  bet_slip { Fabricate(:bet_slip, status: "won", result: "win") }
end

Fabricator(:settled_losing_bet, from: :bet) do
  status { "settled" }
  result { "loss" }
  bet_slip { Fabricate(:bet_slip, status: "lost", result: "loss") }
end

# Refunded bet
Fabricator(:refunded_bet, from: :bet) do
  status { "refunded" }
  result { "refund" }
  void_factor { 1.0 }
  reason { "Match postponed" }
end

# Half-void bet (partial refund)
Fabricator(:half_void_bet, from: :bet) do
  status { "settled" }
  result { "half_void" }
  void_factor { 0.5 }
  reason { "Asian handicap half loss/win" }
end
