Fabricator(:sport) do
  ext_sport_id { sequence(:ext_sport_id) }
  name { |attrs| "Sport #{attrs[:ext_sport_id]}" }
end

Fabricator(:football, from: :sport) do
  ext_sport_id { 1 }
  name { "Football" }
end

Fabricator(:basketball, from: :sport) do
  ext_sport_id { 2 }
  name { "Basketball" }
end

Fabricator(:tennis, from: :sport) do
  ext_sport_id { 5 }
  name { "Tennis" }
end
