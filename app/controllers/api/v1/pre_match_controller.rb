class Api::V1::PreMatchController < Api::V1::BaseController
  skip_before_action :verify_authenticity_token
  # include Pagy::Method

  def index
    # find all fixtures that are not started yet
    # show league, tournament, home and away teams, scores, match time, odds for main markets
    # ===============================
    # Add Caching to speed up response time and set it to 5 minutes
    # ===============================
    raw_results = Rails.cache.fetch("pre_match_fixtures_all", expires_in: 2.minutes) do
      query_sql = <<-SQL
        SELECT DISTINCT ON (f.id)
          f.id,
          f.event_id, 
          f.start_date,
          f.part_one_name AS home_team,
          f.part_two_name AS away_team, 
          f.match_status, 
          f.status AS fixture_status,
          -- Sport Fields
          s.id AS sport_id,
          s.ext_sport_id,
          s.name AS sports_name, 
          -- Tournament Fields
          t.name AS tournament_name,
          f.ext_tournament_id,
          t.id AS tournament_id,
          -- Category Fields 
          f.ext_category_id,
          c.id AS category_id,
          c.name AS category_name,
          -- Markets Fields --
          pm.id AS pre_market_id,
          pm.market_identifier,
          m.name AS market_name,
          m.id AS market_id,
          pm.odds,
          pm.specifier
        FROM fixtures f    
        INNER JOIN pre_markets pm ON pm.fixture_id = f.id AND pm.market_identifier = '1' AND pm.status IN ('active', '0') 
        LEFT JOIN sports s ON CAST(f.sport_id AS INTEGER) = s.ext_sport_id
        LEFT JOIN tournaments t ON f.ext_tournament_id = t.ext_tournament_id
        LEFT JOIN categories c ON f.ext_category_id = c.ext_category_id
        LEFT JOIN markets m ON m.ext_market_id = CAST(pm.market_identifier AS INTEGER)
        WHERE f.match_status = 'not_started' 
          AND f.status IN ('0', 'active') 
          AND f.start_date > NOW()
        ORDER BY f.id, f.start_date ASC
      SQL

      ActiveRecord::Base.connection.exec_query(query_sql).to_a
    end

    @pagy, @records = pagy(:offset, raw_results)

    # make a nested json response
    response = {
      current_page: @pagy.page,
      total_pages: @pagy.pages,
      total_count: @pagy.count,
      fixtures: @records.map do |record|
        {
          id: record["id"],
          event_id: record["event_id"],
          start_date: record["start_date"],
          home_team: record["home_team"],
          away_team: record["away_team"],
          match_status: record["match_status"],
          fixture_status: record["fixture_status"],
          sport: {
            id: record["sport_id"],
            ext_sport_id: record["ext_sport_id"],
            name: record["sports_name"]
          },
          tournament: {
            id: record["tournament_id"],
            ext_tournament_id: record["ext_tournament_id"],
            name: record["tournament_name"]
          },
          category: {
            id: record["category_id"],
            ext_category_id: record["ext_category_id"],
            name: record["category_name"]
          },
          markets: {
            id: record["pre_market_id"],
            name: record["market_name"],
            market_identifier: record["market_identifier"],
            odds: record["odds"] ? JSON.parse(record["odds"]) : {}, 
            specifier: record["specifier"]
          }
        }
      end
    }

    render json: response
  end

  def show
    fixture_id = params[:id]
    # show details for a specific pre-match and all markets/odds
    
    # ===============================
    # Add Caching to speed up response time and set it to 5 minutes
    # ===============================
    raw_results = Rails.cache.fetch("pre_match_fixtures_all", expires_in: 2.minutes) do
      query_sql = <<-SQL
        WITH aggregated_markets AS (
          SELECT
            pm.fixture_id,
            JSON_AGG(
              DISTINCT jsonb_build_object(
                'id', pm.id,
                'name', m.name,
                'market_identifier', pm.market_identifier,
                'odds', pm.odds, 
                'specifier', pm.specifier
              )
            ) AS markets
          FROM pre_markets pm
          LEFT JOIN markets m on m.ext_market_id = pm.market_identifier::integer
          WHERE pm.status IN  ('active', '0')
          GROUP BY pm.fixture_id
        )  
      
        SELECT 
          f.id, 
          f.event_id, 
          f.start_date,
          f.part_one_name AS home_team,
          f.part_two_name AS away_team, 
          f.match_status, 
          f.status AS fixture_status,
          -- Sport Fields
          s.id AS sport_id,
          s.name AS sports_name, 
          s.ext_sport_id,
          -- Tournament Fields
          t.name AS tournament_name,
          t.ext_tournament_id,
          t.id AS tournament_id,
          -- Category Fields 
          c.id AS category_id,
          c.name AS category_name,
          c.ext_category_id,
          am.markets AS markets
        FROM fixtures f      
        LEFT JOIN sports s ON f.sport_id::integer = s.ext_sport_id
        LEFT JOIN tournaments t ON f.ext_tournament_id = t.ext_tournament_id
        LEFT JOIN categories c ON c.ext_category_id = f.ext_category_id
        LEFT JOIN aggregated_markets am ON am.fixture_id = f.id
        WHERE f.match_status = 'not_started' 
          AND f.status IN ('0', 'active') 
          AND f.start_date > NOW()
          AND f.id = #{fixture_id}
        ORDER BY f.start_date DESC
        LIMIT 1
      SQL

      ActiveRecord::Base.connection.exec_query(query_sql).to_a
    end

    if raw_results.empty?
      render json: { error: "Fixture with id #{fixture_id} not found or not available." }, status: :not_found
      return
    end

    response = raw_results.map do |record|
      {
        id: record["id"],
        event_id: record["event_id"],
        start_date: record["start_date"],
        home_team: record["home_team"],
        away_team: record["away_team"],
        match_status: record["match_status"],
        fixture_status: record["fixture_status"],
        sport: {
          id: record["sport_id"],
          ext_sport_id: record["ext_sport_id"],
          name: record["sports_name"]
        },
        tournament: {
          id: record["tournament_id"],
          ext_tournament_id: record["ext_tournament_id"],
          name: record["tournament_name"]
        },
        category: {
          id: record["category_id"],
          ext_category_id: record["ext_category_id"],
          name: record["category_name"]
        },
        markets: record["markets"] ? JSON.parse(record["markets"]) : []
      }
    end
    render json: response
  end
end
