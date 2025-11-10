Fabricator(:category) do
  ext_category_id { sequence(:ext_category_id) { |i| 100 + i } }
  sport
  name { |attrs| "Category #{attrs[:ext_category_id]}" }
end

Fabricator(:premier_league, from: :category) do
  ext_category_id { 100 }
  name { "England - Premier League" }
  sport { Fabricate(:football) }
end

Fabricator(:la_liga, from: :category) do
  ext_category_id { 101 }
  name { "Spain - La Liga" }
  sport { Fabricate(:football) }
end

Fabricator(:nba, from: :category) do
  ext_category_id { 200 }
  name { "USA - NBA" }
  sport { Fabricate(:basketball) }
end
