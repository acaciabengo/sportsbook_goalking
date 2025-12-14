Fabricator(:category) do
  ext_category_id { sequence(:ext_category_id) { |i| 100 + i } }
  sport { Sport.find_by(ext_sport_id: 1) || Fabricate(:football) }
  name { |attrs| "Category #{attrs[:ext_category_id]}" }
end

Fabricator(:premier_league, from: :category) do
  ext_category_id { 100 }
  name { "England - Premier League" }
  sport { Sport.find_by(ext_sport_id: 1) || Fabricate(:football) }
end

Fabricator(:la_liga, from: :category) do
  ext_category_id { 101 }
  name { "Spain - La Liga" }
  sport { Sport.find_by(ext_sport_id: 1) || Fabricate(:football) }
end

Fabricator(:nba, from: :category) do
  ext_category_id { 200 }
  name { "USA - NBA" }
  sport { Sport.find_by(ext_sport_id: 2) || Fabricate(:basketball) }
end
