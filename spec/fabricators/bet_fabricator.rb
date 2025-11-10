Fabricator(:bet) do
  fixture
  market_identifier { 10 }
  specifier { nil }
  outcome { "1" }
  outcome_id { 1 }
  odds { 2.15 }
  amount { 1000 }
  potential_payout { |attrs| (attrs[:amount] * attrs[:odds]).round(2) }
  status { "Active" }
  result { nil }
  void_factor { nil }
  user_id { sequence(:user_id) { |i| 1000 + i } }
  bet_type { "single" }
  placed_at { Time.current }
end

Fabricator(:winning_bet, from: :bet) do
  result { "Win" }
  status { "Closed" }
end

Fabricator(:losing_bet, from: :bet) do
  result { "Loss" }
  status { "Closed" }
end

Fabricator(:void_bet, from: :bet) do
  result { "Void" }
  status { "Closed" }
  void_factor { 1.0 }
end

Fabricator(:partial_void_bet, from: :bet) do
  result { "Void" }
  status { "Closed" }
  void_factor { 0.5 }
end

Fabricator(:pending_bet, from: :bet) do
  status { "Pending" }
  result { nil }
end

Fabricator(:cancelled_bet, from: :bet) do
  status { "Cancelled" }
  result { "Cancelled" }
end

# For Over/Under bets
Fabricator(:over_bet, from: :bet) do
  market_identifier { 11 }
  specifier { "total=2.5" }
  outcome { "Over" }
  outcome_id { 4 }
  odds { 1.85 }
end

Fabricator(:under_bet, from: :bet) do
  market_identifier { 11 }
  specifier { "total=2.5" }
  outcome { "Under" }
  outcome_id { 5 }
  odds { 1.95 }
end

# For 1X2 bets
Fabricator(:home_win_bet, from: :bet) do
  outcome { "1" }
  outcome_id { 1 }
end

Fabricator(:draw_bet, from: :bet) do
  outcome { "X" }
  outcome_id { 2 }
  odds { 3.20 }
end

Fabricator(:away_win_bet, from: :bet) do
  outcome { "2" }
  outcome_id { 3 }
  odds { 3.50 }
end

# For combo/accumulator bets
Fabricator(:combo_bet, from: :bet) do
  bet_type { "combo" }
  odds { 5.75 }
  amount { 500 }
  potential_payout { 2875 }
end

# For system bets
Fabricator(:system_bet, from: :bet) do
  bet_type { "system" }
  odds { 3.5 }
  amount { 750 }
  potential_payout { 2625 }
end
