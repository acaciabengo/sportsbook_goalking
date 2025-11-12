Fabricator(:pre_market) do
  fixture
  market_identifier { sequence(:market_identifier) { |i| 10 + i } }
  odds { {} }
  status { "active" }
end

Fabricator(:pre_market_1x2, from: :pre_market) do
  market_identifier { 10 }
  odds { { "1" => 2.15, "X" => 3.20, "2" => 3.50 } }
end

Fabricator(:pre_market_over_under, from: :pre_market) do
  market_identifier { 18 }
  odds { { "Over" => 1.85, "Under" => 1.95 } }
end

Fabricator(:pre_market_both_teams_score, from: :pre_market) do
  market_identifier { 29 }
  odds { { "Yes" => 1.75, "No" => 2.05 } }
end

Fabricator(:pre_market_double_chance, from: :pre_market) do
  market_identifier { 10 }
  odds { { "1X" => 1.35, "12" => 1.40, "X2" => 1.80 } }
end

Fabricator(:pre_market_asian_handicap, from: :pre_market) do
  market_identifier { 16 }
  odds { { "1" => 1.90, "2" => 1.90 } }
end

Fabricator(:pre_market_correct_score, from: :pre_market) do
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
    }
  end
end

Fabricator(:pre_market_half_time_full_time, from: :pre_market) do
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
    }
  end
end

Fabricator(:pre_market_draw_no_bet, from: :pre_market) do
  market_identifier { 12 }
  odds { { "1" => 1.65, "2" => 2.20 } }
end

Fabricator(:pre_market_odd_even, from: :pre_market) do
  market_identifier { 21 }
  odds { { "Odd" => 1.90, "Even" => 1.90 } }
end

Fabricator(:pre_market_first_half_result, from: :pre_market) do
  market_identifier { 60 }
  odds { { "1" => 2.80, "X" => 2.10, "2" => 3.50 } }
end

Fabricator(:pre_market_with_fixture, from: :pre_market) do
  fixture do
    Fabricate(
      :fixture,
      home_team: "Manchester United",
      away_team: "Liverpool",
      status: "not_started"
    )
  end
  market_identifier { 10 }
  odds { { "1" => 2.50, "X" => 3.40, "2" => 2.80 } }
end

Fabricator(:suspended_pre_market, from: :pre_market) do
  status { "suspended" }
  odds { { "1" => 2.15, "X" => 3.20, "2" => 3.50 } }
end

Fabricator(:closed_pre_market, from: :pre_market) do
  status { "closed" }
  odds { { "1" => 2.15, "X" => 3.20, "2" => 3.50 } }
end

Fabricator(:pre_market_empty_odds, from: :pre_market) { odds { {} } }

Fabricator(:pre_market_partial_odds, from: :pre_market) do
  market_identifier { 10 }
  odds do
    {
      "1" => 2.15
      # Missing X and 2
    }
  end
end

# Basketball pre-markets
Fabricator(:pre_market_basketball_money_line, from: :pre_market) do
  market_identifier { 219 }
  fixture do
    Fabricate(
      :fixture,
      home_team: "Lakers",
      away_team: "Celtics",
      sport: Fabricate(:basketball)
    )
  end
  odds { { "1" => 1.85, "2" => 1.95 } }
end

Fabricator(:pre_market_basketball_handicap, from: :pre_market) do
  market_identifier { 223 }
  fixture { Fabricate(:fixture, sport: Fabricate(:basketball)) }
  odds { { "1" => 1.90, "2" => 1.90 } }
end

Fabricator(:pre_market_basketball_total, from: :pre_market) do
  market_identifier { 226 }
  fixture { Fabricate(:fixture, sport: Fabricate(:basketball)) }
  odds { { "Over" => 1.85, "Under" => 1.95 } }
end
