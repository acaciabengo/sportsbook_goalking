Fabricator(:fixture) do
  event_id { sequence(:event_id) { |i| 100_000 + i } }
  sport_id { 1 }
  ext_category_id { 100 }
  ext_tournament_id { 500 }
  start_date { 1.day.from_now }
  match_status { "1" }
  part_one_id { sequence(:part_one_id) { |i| 9000 + i } }
  part_one_name { |attrs| "Team A #{attrs[:part_one_id]}" }
  part_two_id { sequence(:part_two_id) { |i| 10_000 + i } }
  part_two_name { |attrs| "Team B #{attrs[:part_two_id]}" }
  match_status { "not_started" }
end
