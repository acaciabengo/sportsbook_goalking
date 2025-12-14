Fabricator(:tournament) do
  ext_tournament_id { sequence(:ext_tournament_id) { |i| 1000 + i } }
  name { |attrs| "Tournament #{attrs[:ext_tournament_id]}" }
  category
end

# Fabricator(:premier_league, from: :tournament) do
#   ext_tournament_id { 100 }
#   name { "Premier League" }
#   category do
#     Fabricate(
#       :category,
#       ext_category_id: 10,
#       name: "England",
#       sport: Fabricate(:football)
#     )
#   end
# end

Fabricator(:championship, from: :tournament) do
  ext_tournament_id { 101 }
  name { "Championship" }
  category do
    Fabricate(
      :category,
      ext_category_id: 10,
      name: "England",
      sport: Sport.find_by(ext_sport_id: 1) || Fabricate(:football)
    )
  end
end

# Fabricator(:la_liga, from: :tournament) do
#   ext_tournament_id { 200 }
#   name { "La Liga" }
#   category do
#     Fabricate(
#       :category,
#       ext_category_id: 20,
#       name: "Spain",
#       sport: Fabricate(:football)
#     )
#   end
# end

Fabricator(:bundesliga, from: :tournament) do
  ext_tournament_id { 300 }
  name { "Bundesliga" }
  category do
    Fabricate(
      :category,
      ext_category_id: 30,
      name: "Germany",
      sport: Sport.find_by(ext_sport_id: 1) || Fabricate(:football)
    )
  end
end

Fabricator(:serie_a, from: :tournament) do
  ext_tournament_id { 400 }
  name { "Serie A" }
  category do
    Fabricate(
      :category,
      ext_category_id: 40,
      name: "Italy",
      sport: Sport.find_by(ext_sport_id: 1) || Fabricate(:football)
    )
  end
end

Fabricator(:ligue_1, from: :tournament) do
  ext_tournament_id { 500 }
  name { "Ligue 1" }
  category do
    Fabricate(
      :category,
      ext_category_id: 50,
      name: "France",
      sport: Sport.find_by(ext_sport_id: 1) || Fabricate(:football)
    )
  end
end

Fabricator(:champions_league, from: :tournament) do
  ext_tournament_id { 600 }
  name { "UEFA Champions League" }
  category do
    Fabricate(
      :category,
      ext_category_id: 100,
      name: "Europe",
      sport: Sport.find_by(ext_sport_id: 1) || Fabricate(:football)
    )
  end
end

Fabricator(:europa_league, from: :tournament) do
  ext_tournament_id { 601 }
  name { "UEFA Europa League" }
  category do
    Fabricate(
      :category,
      ext_category_id: 100,
      name: "Europe",
      sport: Sport.find_by(ext_sport_id: 1) || Fabricate(:football)
    )
  end
end

# Basketball tournaments
Fabricator(:nba_tournament, from: :tournament) do
  ext_tournament_id { 1000 }
  name { "NBA" }
  category do
    Fabricate(
      :category,
      ext_category_id: 200,
      name: "USA",
      sport: Sport.find_by(ext_sport_id: 2) || Fabricate(:basketball)
    )
  end
end

Fabricator(:euroleague, from: :tournament) do
  ext_tournament_id { 1100 }
  name { "EuroLeague" }
  category do
    Fabricate(
      :category,
      ext_category_id: 100,
      name: "Europe",
      sport: Sport.find_by(ext_sport_id: 2) || Fabricate(:basketball)
    )
  end
end
