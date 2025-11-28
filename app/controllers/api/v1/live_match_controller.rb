class Api::V1::LiveMatchController < Api::V1::BaseController

  # include Pagy::Method

  def index
    # find all fixtures that are not started yet
    # show league, tournament, home and away teams, scores, match time, odds for main markets
    query_sql = <<-SQL
      SELECT 
        f.id AS fixture_id, 
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
        -- Markets Fields --
        lm.id AS live_market_id,
        lm.ext_market_id,
        m.name AS market_name,
        lm.odds
      FROM fixtures f      
      LEFT JOIN sports s ON f.sport_id = s.id
      LEFT JOIN tournaments t ON f.ext_tournament_id = t.id -- Verify this join condition matches your DB types
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN live_markets lm ON lm.fixture_id = f.id AND lm.ext_market_id = 1 
      LEFT JOIN markets m ON m.ext_market_id = lm.ext_market_id
      WHERE f.match_status = 'in_play' 
        AND f.status = 'active' 
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
          fixture_id: record["fixture_id"],
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
          markets: {
            market_id: record["ext_market_id"],
            name: record["market_name"],
            ext_market_id: record["ext_market_id"],
            odds: record["odds"] ? JSON.parse(record["odds"]) : nil
          }
        }
      end
    }

    render json: response
  end

  def show
    event_id = params[:event_id]
    # show details for a specific live match and all markets/odds
    query_sql = <<-SQL
      WITH aggregated_markets AS (
        SELECT
          lm.fixture_id,
          JSON_AGG(jsonb_build_object(
            'name', m.name,
            'ext_market_id', lm.ext_market_id,
            'odds', lm.odds
          )
          ) AS markets
        FROM live_markets lm
        LEFT JOIN markets m on m.ext_market_id = lm.ext_market_id
        WHERE lm.status = 'active'
        GROUP BY lm.fixture_id
      )  
    
      SELECT 
        f.id AS fixture_id, 
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
      LEFT JOIN sports s ON f.sport_id = s.id
      LEFT JOIN tournaments t ON f.ext_tournament_id = t.id
      LEFT JOIN categories c ON t.category_id = c.id
      LEFT JOIN aggregated_markets am ON am.fixture_id = f.id
      WHERE f.match_status = 'in_play' 
        AND f.status = 'active' 
        AND f.event_id = event_id
      ORDER BY f.start_date DESC
      LIMIT 1
    SQL

    raw_results = ActiveRecord::Base.connection.exec_query(query_sql).to_a

    if raw_results.empty?
      render json: { error: "Fixture with event_id #{event_id} not found or not available." }, status: :not_found
      return
    end

    response = raw_results.map do |record|
      {
        fixture_id: record["fixture_id"],
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
