class Api::V1::PreMatchController < Api::V1::BaseController
  # include Pagy::Method

  def index
    # find all fixtures that are not started yet
    # show league, tournament, home and away teams, scores, match time, odds for main markets
    query_sql = <<-SQL
      SELECT 
        f.id, 
        f.event_id, 
        f.start_date,
        f.part_one_name AS home_team,
        f.part_two_name AS away_team, 
        f.match_status, 
        f.status AS fixture_status,
        -- Sport Fields
        f.sport_id,
        s.name AS sport_name, 
        -- Tournament Fields
        t.name AS tournament_name,
        f.ext_tournament_id,
        -- Category Fields 
        f.ext_category_id,
        c.id AS category_id,
        c.name AS category_name,
        -- Markets Fields --
        pm.id AS pre_market_id,
        pm.market_identifier,
        m.name AS market_name,
        m.id AS market_id,
        pm.odds
      FROM fixtures f      
      LEFT JOIN sports s ON CAST(f.sport_id AS INTEGER) = s.ext_sport_id
      LEFT JOIN tournaments t ON f.ext_tournament_id = t.id 
      LEFT JOIN categories c ON f.ext_category_id = c.ext_category_id
      LEFT JOIN pre_markets pm ON pm.fixture_id = f.id 
      LEFT JOIN markets m ON m.ext_market_id = CAST(pm.market_identifier AS INTEGER) 
      WHERE f.match_status = 'not_started' 
        AND f.status = 'active' 
        AND f.start_date > NOW()
        AND pm.market_identifier = '1'

      ORDER BY f.start_date ASC
    SQL

    raw_results = ActiveRecord::Base.connection.exec_query(query_sql).to_a

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
            name: record["sport_name"]
          },
          tournament: {
            id: record["tournament_id"],
            name: record["tournament_name"]
          },
          category: {
            id: record["category_id"],
            name: record["category_name"]
          },
          markets: {
            id: record["market_id"],
            name: record["market_name"],
            market_id: record["market_identifier"],
            odds: record["odds"]
          }
        }
      end
    }

    render json: response
  end

  def show
    fixture_id = params[:id]
    # show details for a specific pre-match and all markets/odds
    query_sql = <<-SQL
      WITH aggregated_markets AS (
        SELECT
          pm.fixture_id,
          JSON_AGG(jsonb_build_object(
            'name', m.name,
            'market_id', pm.market_identifier::integer,
            'odds', pm.odds
          )
          ) AS markets
        FROM pre_markets pm
        LEFT JOIN markets m on m.ext_market_id = pm.market_identifier::integer
        WHERE pm.status = 'active'
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
        f.sport_id,
        s.name AS sport_name, 
        -- Tournament Fields
        t.name AS tournament_name,
        f.ext_tournament_id AS tournament_id,
        -- Category Fields 
        c.id AS category_id,
        c.name AS category_name,
        am.markets AS markets
      FROM fixtures f      
      LEFT JOIN sports s ON f.sport_id::integer = s.ext_sport_id
      LEFT JOIN tournaments t ON f.ext_tournament_id = t.id 
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN aggregated_markets am ON am.fixture_id = f.id
      WHERE f.match_status = 'not_started' 
        AND f.status = 'active' 
        AND f.start_date > NOW()
        AND f.id = #{fixture_id}
      ORDER BY f.start_date DESC
      LIMIT 1
    SQL

    raw_results = ActiveRecord::Base.connection.exec_query(query_sql).to_a

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
          sport_id: record["sport_id"],
          sport_name: record["sport_name"]
        },
        tournament: {
          tournament_id: record["tournament_id"],
          tournament_name: record["tournament_name"]
        },
        category: {
          category_id: record["category_id"],
          category_name: record["category_name"]
        },
        markets: record["markets"] ? JSON.parse(record["markets"]) : []
      }
    end
    render json: response
  end
end
