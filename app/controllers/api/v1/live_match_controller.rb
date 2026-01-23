class Api::V1::LiveMatchController < Api::V1::BaseController
  skip_before_action :verify_authenticity_token
  # before_action :auth_user

  def index
    # find all fixtures that are not started yet
    # show league, tournament, home and away teams, scores, match time, odds for main markets
    
    #extract filter params if any
    sport_id = params[:sport_id]&.to_i
    category_id = params[:category_id]&.to_i
    tournament_id = params[:tournament_id]&.to_i
    query = params[:query]&.strip
    page = params[:page]&.to_i || 1

    dynamic_conditions = []

    binds = []

    if sport_id.present?
      dynamic_conditions << "s.id = ?"
      binds << sport_id
    end

    if category_id.present?
      dynamic_conditions << "c.id = ?"
      binds << category_id
    end

    if tournament_id.present?
      dynamic_conditions << "t.id = ?"
      binds << tournament_id
    end

    if query.present?
      dynamic_conditions << "(f.part_one_name ILIKE ? OR f.part_two_name ILIKE ?)"
      binds << "%#{query}%" << "%#{query}%"
    end

    if dynamic_conditions.any?
      dynamic_sql = "AND " + dynamic_conditions.join(" AND ")
    else
      dynamic_sql = ""
    end

    # Repeat binds for each CTE and main query (3 times total)
    sanitized_binds = binds + binds + binds

    query_sql = <<-SQL
        -- aggregate markets into a json array per fixture
        WITH aggregated_markets AS (
          SELECT
            lm.fixture_id,
            lm.market_identifier,
            lm.id AS live_market_id,
            lm.name,
            lm.odds,
            lm.specifier,
            lm.status AS status
          FROM live_markets lm
          JOIN fixtures f ON f.id = lm.fixture_id
          LEFT JOIN sports s ON CAST(f.sport_id AS INTEGER) = s.ext_sport_id
          LEFT JOIN tournaments t ON f.ext_tournament_id = t.ext_tournament_id
          LEFT JOIN categories c ON f.ext_category_id = c.ext_category_id
          WHERE
            lm.status = 'started'
            AND lm.market_identifier = '2'
            AND f.live_odds = '1'
            AND f.booked = true
            AND f.match_status = '1' 
            AND f.status = '1'
            AND f.start_date >= NOW() - INTERVAL '2 hours'
            #{dynamic_sql}
        ), 
        market_counts AS (
          SELECT 
            lm.fixture_id, 
            COUNT(*) AS total_markets
          FROM live_markets lm
          JOIN fixtures f ON f.id = lm.fixture_id
          LEFT JOIN sports s ON CAST(f.sport_id AS INTEGER) = s.ext_sport_id
          LEFT JOIN tournaments t ON f.ext_tournament_id = t.ext_tournament_id
          LEFT JOIN categories c ON f.ext_category_id = c.ext_category_id
          WHERE lm.status = 'started'
            AND f.live_odds = '1'
            AND f.booked = true
            AND f.match_status = '1'
            AND f.status = '1'
            AND f.start_date >= NOW() - INTERVAL '2 hours'
            #{dynamic_sql}
          GROUP BY lm.fixture_id
        )

        SELECT
          f.id, 
          f.event_id, 
          f.start_date,
          f.part_one_name AS home_team,
          f.part_two_name AS away_team, 
          f.match_status, 
          f.status AS fixture_status,
          f.match_time,
          f.home_score,
          f.away_score,
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
          -- Markets Fields (Only for Market ID '2')
          am.live_market_id,
          am.market_identifier,
          am.name AS market_name,
          am.odds,
          am.specifier,
          am.status,
          mc.total_markets AS market_count

        FROM fixtures f
        INNER JOIN aggregated_markets am ON am.fixture_id = f.id
        INNER JOIN market_counts mc ON mc.fixture_id = f.id
        LEFT JOIN sports s ON CAST(f.sport_id AS INTEGER) = s.ext_sport_id
        LEFT JOIN tournaments t ON f.ext_tournament_id = t.ext_tournament_id
        LEFT JOIN categories c ON f.ext_category_id = c.ext_category_id
        WHERE 
          f.live_odds = '1'
          AND f.booked = true
          AND f.match_status = '1'
          AND f.status = '1'
          AND f.start_date >= NOW() - INTERVAL '2 hours'
          #{dynamic_sql}
        ORDER BY f.start_date ASC
      SQL

    final_sql = ActiveRecord::Base.sanitize_sql_array([query_sql] + sanitized_binds)
    raw_results = ActiveRecord::Base.connection.exec_query(final_sql).to_a

    # No need to filter - INNER JOIN ensures all fixtures have active markets
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
          match_time: record["match_time"],
          score: "#{record["home_score"]}-#{record["away_score"]}",
          market_count: record["market_count"],
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
            id: record["live_market_id"],
            name: record["market_name"],
            market_identifier: record["market_identifier"],
            odds: record["odds"] ? format_odds(record["home_team"], record["away_team"], JSON.parse(record["odds"]), record["specifier"]) : {},
            specifier: record["specifier"],
            status: record["status"]
          }
        }
      end
    }

    render json: response
  end

  def show
    fixture_id = params[:id]
    
    # show details for a specific live match and all markets/odds
    
    query_sql = <<-SQL
        WITH aggregated_markets AS (
          SELECT
            lm.fixture_id,
            JSON_AGG(
              DISTINCT jsonb_build_object(
                'id', lm.id,
                'name', lm.name,
                'market_identifier', lm.market_identifier,
                'odds', lm.odds::jsonb,
                'specifier', lm.specifier,
                'status', lm.status
              )
            ) AS markets
          FROM live_markets lm
          WHERE lm.status = 'started'
          GROUP BY lm.fixture_id
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
        WHERE f.live_odds = '1'
          AND f.booked = true
          AND f.status = '1'
          AND f.match_status = '1'
          AND f.start_date >= NOW() - INTERVAL '2 hours'
          AND f.id = $1
        ORDER BY f.start_date DESC
        LIMIT 1
      SQL

    raw_results = ActiveRecord::Base.connection.exec_query(query_sql, "SQL", [fixture_id]).to_a
    

    if raw_results.empty?
      render json: { error: "Fixture with event_id #{fixture_id} not found or not available." }, status: :not_found
      return
    end

    raw_results = raw_results.sort_by { |r| r['start_date'] }

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
        markets: record["markets"] ? JSON.parse(record["markets"]).map do |market|
          market["odds"] = format_odds(record["home_team"], record["away_team"], market["odds"], market["specifier"])
          market["name"] = format_market_names(record["home_team"], record["away_team"], market["name"], market["specifier"])
          market
        end : []
      }
    end
    
    render json: response
  end

  private

  def format_odds(competitor1, competitor2, odds_data, specifier)
    return {} if odds_data.blank?

    # Handle both JSON string and Hash
    odds = odds_data.is_a?(String) ? JSON.parse(odds_data) : odds_data

    # extract all odds keys and return if no placeholders found
    # Use safe navigation & check for string keys
    odds_keys = odds.keys.map(&:to_s)

    # Check for any placeholder presence using regex
    has_placeholders = odds_keys.any? { |key| key.match?(/\{.*?\}/) }

    return odds unless has_placeholders
    
    formatted_odds = {}

    odds.each do |key, value|
      new_key = key.to_s.gsub(/\{.*?\}/) do |match|
        case match
        when '{$competitor1}'
          competitor1.to_s
        when '{$competitor2}'
          competitor2.to_s
        else
          if specifier.present?
            if match.include?('+')
              "+#{specifier}"
            elsif match.include?('-')
              "-#{specifier}"
            else
              specifier.to_s
            end
          else
            match
          end
        end
      end
      
      formatted_odds[new_key] = value
    end

    formatted_odds
  end

  def format_market_names(competitor1, competitor2, market_name, specifier)
    return market_name if market_name.blank?

    # check if there are any placeholders using regex
    has_placeholders = market_name.match?(/\{.*?\}/)

    if has_placeholders
      new_market_name = market_name + " " + specifier
      return new_market_name
    end

    new_market_name = market_name.gsub(/\{.*?\}/) do |match|
      case match
      when '{$competitor1}'
        competitor1.to_s
      when '{$competitor2}'
        competitor2.to_s
      else
        if specifier.present?
          if match.include?('+')
            "+#{specifier}"
          elsif match.include?('-')
            "-#{specifier}"
          else
            specifier.to_s
          end
        else
          match
        end
      end
    end

    new_market_name
  end
end