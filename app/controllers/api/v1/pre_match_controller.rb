class Api::V1::PreMatchController < Api::V1::BaseController
  skip_before_action :verify_authenticity_token
  # include Pagy::Method

  def index
    # find all fixtures that are not started yet
    # show league, tournament, home and away teams, scores, match time, odds for main markets

    sport_id = params[:sport_id].presence&.to_i
    category_id = params[:category_id].presence&.to_i
    tournament_id = params[:tournament_id].presence&.to_i
    query = params[:query]&.strip.presence
    page = (params[:page].presence || 1).to_i
    per_page = 20
    offset = (page - 1) * per_page

    # Build filter conditions once
    filter_key = [sport_id || 'all', category_id || 'all', tournament_id || 'all', query || 'none'].join(":")

    # ===============================
    # Cache total count separately (changes less frequently)
    # ===============================
    count_cache_key = "pre_match_count_v3:#{filter_key}"
    total_count = Rails.cache.fetch(count_cache_key, expires_in: 10.minutes) do
      fetch_pre_match_count(sport_id, category_id, tournament_id, query)
    end

    total_pages = (total_count / per_page.to_f).ceil

    # ===============================
    # Cache paginated results
    # ===============================
    cache_key = "pre_match_v3:#{filter_key}:page:#{page}"

    fixtures = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      fetch_pre_match_fixtures(sport_id, category_id, tournament_id, query, per_page, offset)
    end

    render json: {
      current_page: page,
      total_pages: total_pages,
      total_count: total_count,
      fixtures: fixtures
    }
  end

  def show
    fixture_id = params[:id]

    cache_key = "pre_match_fixture_v3_#{fixture_id}"

    response = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
      query_sql = <<-SQL
        WITH aggregated_markets AS (
          SELECT
            pm.fixture_id,
            JSON_AGG(
              DISTINCT jsonb_build_object(
                'id', pm.id,
                'name', m.name,
                'market_identifier', pm.market_identifier,
                'odds', pm.odds::jsonb,
                'specifier', pm.specifier,
                'status', pm.status
              )
            ) AS markets
          FROM pre_markets pm
          LEFT JOIN markets m on m.ext_market_id = pm.market_identifier::integer
          WHERE pm.status IN ('active', '0')
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
          s.id AS sport_id,
          s.name AS sports_name,
          s.ext_sport_id,
          t.name AS tournament_name,
          t.ext_tournament_id,
          t.id AS tournament_id,
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
          AND f.id = $1
        LIMIT 1
      SQL

      raw_results = ActiveRecord::Base.connection.exec_query(query_sql, "SQL", [fixture_id]).to_a
      next nil if raw_results.empty?

      raw_results.map do |record|
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
            market["name"] = format_market_names(record["home_team"], record["away_team"], market["name"], market["specifier"], market["odds"])
            market
          end : []
        }
      end
    end

    if response.nil?
      render json: { error: "Fixture not found or not available." }, status: :not_found
      return
    end

    render json: response
  end

  private

  def build_filter_conditions(sport_id, category_id, tournament_id, query)
    conditions = []
    binds = []

    if sport_id.present?
      conditions << "s.id = ?"
      binds << sport_id
    end

    if category_id.present?
      conditions << "c.id = ?"
      binds << category_id
    end

    if tournament_id.present?
      conditions << "t.id = ?"
      binds << tournament_id
    end

    if query.present?
      conditions << "(f.part_one_name ILIKE ? OR f.part_two_name ILIKE ?)"
      binds << "%#{query}%" << "%#{query}%"
    end

    dynamic_sql = conditions.any? ? "AND " + conditions.join(" AND ") : ""
    [dynamic_sql, binds]
  end

  def fetch_pre_match_count(sport_id, category_id, tournament_id, query)
    dynamic_sql, binds = build_filter_conditions(sport_id, category_id, tournament_id, query)

    count_sql = <<-SQL
      SELECT COUNT(DISTINCT f.id)
      FROM fixtures f
      INNER JOIN pre_markets pm ON pm.fixture_id = f.id
      LEFT JOIN sports s ON f.sport_id::integer = s.ext_sport_id
      LEFT JOIN tournaments t ON f.ext_tournament_id = t.ext_tournament_id
      LEFT JOIN categories c ON f.ext_category_id = c.ext_category_id
      WHERE pm.status IN ('active', '0')
        AND pm.market_identifier = '1'
        AND f.match_status = 'not_started'
        AND f.status IN ('0', 'active')
        AND f.start_date > NOW()
        #{dynamic_sql}
    SQL

    result = ActiveRecord::Base.connection.exec_query(
      ActiveRecord::Base.sanitize_sql_array([count_sql] + binds)
    ).first
    result["count"].to_i
  end

  def fetch_pre_match_fixtures(sport_id, category_id, tournament_id, query, limit, offset)
    dynamic_sql, binds = build_filter_conditions(sport_id, category_id, tournament_id, query)

    # Single optimized query with subquery for market count
    query_sql = <<-SQL
      SELECT
        f.id,
        f.event_id,
        f.start_date,
        f.part_one_name AS home_team,
        f.part_two_name AS away_team,
        f.match_status,
        f.status AS fixture_status,
        s.id AS sport_id,
        s.ext_sport_id,
        s.name AS sports_name,
        t.name AS tournament_name,
        f.ext_tournament_id,
        t.id AS tournament_id,
        f.ext_category_id,
        c.id AS category_id,
        c.name AS category_name,
        pm.id AS pre_market_id,
        pm.market_identifier,
        m.name AS market_name,
        m.id AS market_id,
        pm.odds,
        pm.specifier,
        pm.status,
        (SELECT COUNT(*) FROM pre_markets pm2
         WHERE pm2.fixture_id = f.id AND pm2.status IN ('active', '0')) AS market_count
      FROM fixtures f
      INNER JOIN pre_markets pm ON pm.fixture_id = f.id
        AND pm.status IN ('active', '0')
        AND pm.market_identifier = '1'
      LEFT JOIN sports s ON f.sport_id::integer = s.ext_sport_id
      LEFT JOIN tournaments t ON f.ext_tournament_id = t.ext_tournament_id
      LEFT JOIN categories c ON f.ext_category_id = c.ext_category_id
      LEFT JOIN markets m ON m.ext_market_id = pm.market_identifier::integer AND m.sport_id = s.id
      WHERE f.match_status = 'not_started'
        AND f.status IN ('0', 'active')
        AND f.start_date > NOW()
        #{dynamic_sql}
      ORDER BY f.start_date ASC
      LIMIT #{limit} OFFSET #{offset}
    SQL

    final_sql = ActiveRecord::Base.sanitize_sql_array([query_sql] + binds)
    raw_results = ActiveRecord::Base.connection.exec_query(final_sql).to_a

    raw_results.map do |record|
      {
        id: record["id"],
        event_id: record["event_id"],
        start_date: record["start_date"],
        home_team: record["home_team"],
        away_team: record["away_team"],
        match_status: record["match_status"],
        fixture_status: record["fixture_status"],
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
          id: record["pre_market_id"],
          name: record["market_name"],
          market_identifier: record["market_identifier"],
          odds: record["odds"] ? format_odds(record["home_team"], record["away_team"], JSON.parse(record["odds"]), record["specifier"]) : {},
          specifier: record["specifier"],
          status: record["status"]
        }
      }
    end
  end

  def format_odds(competitor1, competitor2, odds_data, specifier)
    return {} if odds_data.blank?

    # Handle both JSON string and Hash
    odds = odds_data.is_a?(String) ? JSON.parse(odds_data) : odds_data

    # If specifier is missing, try to find it inside the odds values
    if specifier.blank?
      first_val = odds.values.first
      if first_val.is_a?(Hash) && first_val['specifier'].present?
        specifier = first_val['specifier']
      end
    end

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

  def format_market_names(competitor1, competitor2, market_name, specifier, odds_data = nil)
    return market_name if market_name.blank?

    # If specifier is missing, try to find it inside the odds values
    if specifier.blank? && odds_data.present?
      odds = odds_data.is_a?(String) ? JSON.parse(odds_data) : odds_data
      first_val = odds.values.first
      if first_val.is_a?(Hash) && first_val['specifier'].present?
        specifier = first_val['specifier']
      end
    end

    # check if there are any placeholders using regex
    has_placeholders = market_name.match?(/\{.*?\}/)

    return market_name unless has_placeholders

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
