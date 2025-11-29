Fabricator(:live_market) do
  fixture
  market_identifier { sequence(:market_identifier) { |i| 10 + i } }
  odds { {} }
  status { "active" }
end

Fabricator(:live_market_1x2, from: :live_market) do
  market_identifier { 1 }
  odds { { "1" => 2.15, "X" => 3.20, "2" => 3.50 }.to_json }
end

Fabricator(:live_market_over_under, from: :live_market) do
  market_identifier { 18 }
  odds { { "over" => 1.85, "under" => 1.95 }.to_json }
end

Fabricator(:live_market_both_teams_score, from: :live_market) do
  market_identifier { 29 }
  odds { { "yes" => 1.75, "no" => 2.05 }.to_json }
end

Fabricator(:live_market_double_chance, from: :live_market) do
  market_identifier { 10 }
  odds { { "1X" => 1.35, "12" => 1.40, "X2" => 1.80 }.to_json }
end

Fabricator(:live_market_asian_handicap, from: :live_market) do
  market_identifier { 16 }
  odds { { "1" => 1.90, "2" => 1.90 }.to_json }
end

Fabricator(:live_market_correct_score, from: :live_market) do
  market_identifier { 14 }
  odds do
    {
      "1:0" => 8.50,
      "2:0" => 10.00,
      "2:1" => 9.00,
      "3:0" => 15.00,
      "3:1" => 14.00,
      "0:0" => 7.50,
      "0:1" => 11.00,
      "0:2" => 15.00,
      "1:1" => 6.50,
      "1:2" => 12.00
    }.to_json
  end
end

Fabricator(:live_market_half_time_full_time, from: :live_market) do
  market_identifier { 11 }
  odds do
    {
      "1/1" => 3.50,
      "1/X" => 8.00,
      "1/2" => 15.00,
      "X/1" => 7.00,
      "X/X" => 4.50,
      "X/2" => 8.00,
      "2/1" => 20.00,
      "2/X" => 10.00,
      "2/2" => 5.00
    }.to_json
  end
end

Fabricator(:live_market_draw_no_bet, from: :live_market) do
  market_identifier { 12 }
  odds { { "1" => 1.65, "2" => 2.20 }.to_json }
end

Fabricator(:live_market_odd_even, from: :live_market) do
  market_identifier { 21 }
  odds { { "odd" => 1.90, "even" => 1.90 }.to_json }
end

Fabricator(:live_market_next_goal, from: :live_market) do
  market_identifier { 60 }
  odds { { "1" => 2.10, "none" => 5.00, "2" => 3.20 }.to_json }
end

Fabricator(:live_market_with_fixture, from: :live_market) do
  fixture do
    Fabricate(
      :fixture,
      part_one_name: "Manchester United",
      part_two_name: "Liverpool",
      match_status: "in_play"
    )
  end
  market_identifier { 1 }
  odds { { "1" => 2.50, "X" => 3.40, "2" => 2.80 }.to_json }
end

Fabricator(:suspended_live_market, from: :live_market) do
  status { "suspended" }
  odds { { "1" => 2.15, "X" => 3.20, "2" => 3.50 }.to_json }
end

Fabricator(:closed_live_market, from: :live_market) do
  status { "closed" }
  odds { { "1" => 2.15, "X" => 3.20, "2" => 3.50 }.to_json }
end

Fabricator(:inactive_live_market, from: :live_market) do
  status { "inactive" }
  odds { { "1" => 2.15, "X" => 3.20, "2" => 3.50 }.to_json }
end

Fabricator(:live_market_empty_odds, from: :live_market) do
  odds { {}.to_json }
end

Fabricator(:live_market_partial_odds, from: :live_market) do
  market_identifier { 1 }
  odds do
    {
      "1" => 2.15
      # Missing X and 2
    }.to_json
  end
end

# In-play specific markets
Fabricator(:live_market_total_goals, from: :live_market) do
  market_identifier { 26 }
  odds do
    {
      "0-1" => 8.00,
      "2-3" => 2.50,
      "4-6" => 3.20,
      "7+" => 12.00
    }.to_json
  end
end

Fabricator(:live_market_winning_margin, from: :live_market) do
  market_identifier { 65 }
  odds do
    {
      "1_by_1" => 6.50,
      "1_by_2" => 8.00,
      "1_by_3+" => 10.00,
      "2_by_1" => 8.50,
      "2_by_2" => 12.00,
      "2_by_3+" => 15.00
    }.to_json
  end
end

Fabricator(:live_market_time_of_next_goal, from: :live_market) do
  market_identifier { 77 }
  odds do
    {
      "before_60" => 1.75,
      "after_60" => 2.10,
      "no_goal" => 8.00
    }.to_json
  end
end

# Basketball live markets
Fabricator(:live_market_basketball_money_line, from: :live_market) do
  market_identifier { 219 }
  fixture do
    Fabricate(
      :fixture,
      part_one_name: "Lakers",
      part_two_name: "Celtics",
      match_status: "in_play"
    )
  end
  odds { { "1" => 1.85, "2" => 1.95 }.to_json }
end

Fabricator(:live_market_basketball_handicap, from: :live_market) do
  market_identifier { 223 }
  odds { { "1" => 1.90, "2" => 1.90 }.to_json }
end

Fabricator(:live_market_basketball_total, from: :live_market) do
  market_identifier { 226 }
  odds { { "over" => 1.85, "under" => 1.95 }.to_json }
end

Fabricator(:live_market_basketball_quarter, from: :live_market) do
  market_identifier { 235 }
  odds { { "1" => 2.00, "2" => 1.80 }.to_json }
end

# Tennis live markets
Fabricator(:live_market_tennis_match_winner, from: :live_market) do
  market_identifier { 186 }
  fixture do
    Fabricate(
      :fixture,
      part_one_name: "Nadal",
      part_two_name: "Djokovic",
      match_status: "in_play"
    )
  end
  odds { { "1" => 2.20, "2" => 1.70 }.to_json }
end

Fabricator(:live_market_tennis_set_winner, from: :live_market) do
  market_identifier { 188 }
  odds { { "1" => 1.95, "2" => 1.85 }.to_json }
end

Fabricator(:live_market_tennis_game_winner, from: :live_market) do
  market_identifier { 198 }
  odds { { "1" => 1.75, "2" => 2.05 }.to_json }
end

# Ice Hockey live markets
Fabricator(:live_market_hockey_money_line, from: :live_market) do
  market_identifier { 1 }
  fixture do
    Fabricate(
      :fixture,
      part_one_name: "Bruins",
      part_two_name: "Rangers",
      match_status: "in_play"
    )
  end
  odds { { "1" => 2.10, "X" => 4.00, "2" => 2.80 }.to_json }
end

Fabricator(:live_market_hockey_total, from: :live_market) do
  market_identifier { 18 }
  odds { { "over" => 1.90, "under" => 1.90 }.to_json }
end

# Volatile odds (changing rapidly during live play)
Fabricator(:live_market_volatile_odds, from: :live_market) do
  market_identifier { 1 }
  odds do
    # Simulating odds that change during a match
    {
      "1" => rand(1.5..5.0).round(2),
      "X" => rand(2.5..6.0).round(2),
      "2" => rand(1.5..5.0).round(2)
    }.to_json
  end
end

# Markets with very high odds (long shots)
Fabricator(:live_market_high_odds, from: :live_market) do
  market_identifier { 14 }
  odds do
    {
      "5:0" => 50.00,
      "0:5" => 75.00,
      "6:0" => 100.00
    }.to_json
  end
end