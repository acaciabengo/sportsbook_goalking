Fabricator(:market) do
  ext_market_id { sequence(:ext_market_id) { |i| 10 + i } }
  name { |attrs| "Market #{attrs[:ext_market_id]}" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_1x2, from: :market) do
  ext_market_id { 1 }
  name { "1X2" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_over_under, from: :market) do
  ext_market_id { 18 }
  name { "Total" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_both_teams_score, from: :market) do
  ext_market_id { 29 }
  name { "Both Teams To Score" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_double_chance, from: :market) do
  ext_market_id { 10 }
  name { "Double Chance" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_asian_handicap, from: :market) do
  ext_market_id { 16 }
  name { "Asian Handicap" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_correct_score, from: :market) do
  ext_market_id { 14 }
  name { "Correct Score" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_half_time_full_time, from: :market) do
  ext_market_id { 11 }
  name { "Half Time/Full Time" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_draw_no_bet, from: :market) do
  ext_market_id { 12 }
  name { "Draw No Bet" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_odd_even, from: :market) do
  ext_market_id { 21 }
  name { "Odd/Even" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_first_half_result, from: :market) do
  ext_market_id { 60 }
  name { "1st Half Result" }
  sport_id { Fabricate(:football).id }
end

Fabricator(:market_second_half_result, from: :market) do
  ext_market_id { 61 }
  name { "2nd Half Result" }
  sport_id { Fabricate(:football).id }
end

# Basketball markets
Fabricator(:market_basketball_money_line, from: :market) do
  ext_market_id { 219 }
  name { "Money Line" }
  sport_id { Fabricate(:basketball).id }
end

Fabricator(:market_basketball_handicap, from: :market) do
  ext_market_id { 223 }
  name { "Handicap" }
  sport_id { Fabricate(:basketball).id }
end

Fabricator(:market_basketball_total, from: :market) do
  ext_market_id { 226 }
  name { "Total" }
  sport_id { Fabricate(:basketball).id }
end

# Tennis markets
Fabricator(:market_tennis_match_winner, from: :market) do
  ext_market_id { 186 }
  name { "Match Winner" }
  sport_id { Fabricate(:tennis).id }
end

Fabricator(:market_tennis_set_betting, from: :market) do
  ext_market_id { 187 }
  name { "Set Betting" }
  sport_id { Fabricate(:tennis).id }
end
