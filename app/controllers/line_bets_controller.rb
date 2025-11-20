class LineBetsController < ApplicationController
  protect_from_forgery except: %i[refresh line_bet_delete create destroy]
  include CurrentCart
  before_action :set_cart,
                only: %i[
                  create
                  destroy
                  refresh
                  close_betslip_button_display
                  cart_fixtures
                  check_bonus
                ]

  # before_action :set_line_item, only: [:show, :edit, :update, :destroy]

  def create
    outcome = params[:outcome_id] ## Ex: "X"
    market = params[:market] ## Ex: PreMarket or LiveMarket
    identifier = params[:identifier] ## Ex: "1"
    fixture_id = params[:fixture_id].to_i ## Ex: 1090
    description = params[:outcome_desc] ## Ex: "1X2 FT - 2"

    fixture = Fixture.find(fixture_id)

    if params[:specifier].present?
      market_entry = market.constantize.find_by(fixture_id: fixture_id, market_identifier: identifier, specifier: params[:specifier])
    else
      market_entry = market.constantize.find_by(fixture_id: fixture_id, market_identifier: identifier)
    end

    #check if the bet already exists
    @line_bet = LineBet.find_by(fixture_id: fixture.id, cart_id: @cart.id)
    if @line_bet
      @line_bet.assign_attributes(
        outcome: outcome,
        market: market,
        market_identifier: identifier,
        odd: fetch_current_odd(market, identifier, fixture_id, outcome, params[:specifier]),
        description: description,
        specifier: params[:specifier]
      )
    else
      line_bets_count = @cart.line_bets.count()

      if line_bets_count > 49
        render json: {errors: "Maximum number of bets is 50."}, status: 400 and return
      else
        @line_bet =
        @cart.line_bets.build(
          fixture_id: fixture.id,
          outcome: outcome,
          market: market,
          market_identifier: identifier,
          odd: fetch_current_odd(market, identifier, fixture_id, outcome, params[:specifier]),
          description: description,
          specifier: params[:specifier],
          sport: fixture.sport
        )
      end
    end

    ## After adding the line_bet to cart, send all line_bets in cart to react state
    if @line_bet.save 
      cart_fixtures() && return
    end

  end

  def line_bet_delete
    @line_bet = LineBet.find(params[:id])
    @cart = Cart.find(@line_bet.cart_id)
    @line_bet.delete

    render json: { 'status': 'OK' }
  end

  def cart_fixtures
    @games = @cart.line_bets
    fixtures = []
    @games.each do |bet|
      if fetch_market_status(bet.market, bet.market_identifier, bet.fixture_id, bet.specifier) == 'Active'
        fixtures << {
          'cartId': bet.cart_id,
          'fixtureId': bet.fixture_id,
          'partOne': bet.fixture.part_one_name,
          'partTwo': bet.fixture.part_two_name,
          'id': bet.id,
          'market': bet.market,
          'marketIdentifier': bet.market_identifier,
          'description': bet.description,
          'outcome': bet.outcome,
          'odd': fetch_current_odd(bet.market, bet.market_identifier, bet.fixture_id, bet.outcome, bet.specifier),
          "status": "Active"
        }
      end
    end

    render json: fixtures
  end

  def destroy
    @cart.destroy if @cart.id == session[:cart_id]
    session[:cart_id] = nil
    render json: { 'status': 'OK' }
  end

  ## Method to check if there is any bonus and return results to the JS controller
  def check_bonus
    number_of_games = @cart.line_bets.count()
    slip_obj = SlipBonus.where("status = ? AND min_accumulator <= ? AND max_accumulator >= ?", "Active", number_of_games, number_of_games).last
    if !slip_obj.nil?
      multiplier = (slip_obj.multiplier / 100).to_f
    else
      multiplier = 0.0
    end

    render json: multiplier, status: 200
  end

end
