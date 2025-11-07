class BetBalancer
  require "nokogiri"

  AUTH_URL = "https://api.betbalancer.com/v1/authenticate"

  def initialize()
    @client = client()
    @default_params = {
      bookmakerName: ENV["BET_BALANCER_BOOKMAKER_NAME"],
      key: ENV["BET_BALANCER_API_KEY"]
    }
  end

  def client()
    conn =
      Faraday.new(url: AUTH_URL) do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end
    conn
  end

  def get_sports(sport_id: nil)
    params = @default_params.merge({ sportId: sport_id }) if sport_id
    response =
      @client.get do |req|
        req.url "/export/getSports"
        req.headers["Content-Type"] = "application/xml"
        req.params = params || @default_params
      end
    # parse xml
    data = Nokogiri.XML(response.body)
    return data
  end

  def get_categories(sport_id: nil, category_id: nil)
    params = @default_params.duplicate
    params[:sportId] = sport_id if sport_id
    params[:categoryId] = category_id if category_id

    response =
      @client.get do |req|
        req.url "/export/getCategories"
        req.headers["Content-Type"] = "application/xml"
        req.params = params
      end
    # parse xml
    data = Nokogiri.XML(response.body)
    return data
  end

  def get_tournaments(sport_id: nil, category_id: nil, tournament_id: nil)
    params = @default_params.duplicate
    params[:sportId] = sport_id if sport_id
    params[:categoryId] = category_id if category_id
    params[:tournamentId] = tournament_id if tournament_id

    response =
      @client.get do |req|
        req.url "/export/getTournaments"
        req.headers["Content-Type"] = "application/xml"
        req.params = params
      end
    # parse xml
    data = Nokogiri.XML(response.body)
    return data
  end

  def get_markets(
    sport_id: nil,
    category_id: nil,
    tournament_id: nil,
    market_id: nil
  )
    params = @default_params.duplicate
    params[:sportId] = sport_id if sport_id
    params[:categoryId] = category_id if category_id
    params[:tournamentId] = tournament_id if tournament_id
    params[:marketId] = market_id if market_id

    response =
      @client.get do |req|
        req.url "/export/getMarkets"
        req.headers["Content-Type"] = "application/xml"
        req.params = params
      end
    # parse xml
    data = Nokogiri.XML(response.body)
    return data
  end

  def get_matches(
    sport_id: nil,
    category_id: nil,
    tournament_id: nil,
    market_id: nil,
    match_id: nil,
    date_from: nil,
    date_to: nil,
    want_score: nil
  )
    params = @default_params.duplicate
    params[:sportId] = sport_id if sport_id
    params[:categoryId] = category_id if category_id
    params[:tournamentId] = tournament_id if tournament_id
    params[:marketId] = market_id if market_id
    params[:matchId] = match_id if match_id
    params[:dateFrom] = date_from if date_from
    params[:dateTo] = date_to if date_to
    params[:wantScore] = want_score if want_score

    response =
      @client.get do |req|
        req.url "/export/getMatches"
        req.headers["Content-Type"] = "application/xml"
        req.params = params
      end
    # parse xml
    data = Nokogiri.XML(response.body)
    return data
  end
end
