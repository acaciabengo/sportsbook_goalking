class Api::V1::BetslipsController < Api::V1::BaseController
	skip_before_action :verify_authenticity_token
	before_action :auth_user

	def index
		betslips = @current_user.bet_slips.order(created_at: :desc)
		@pagy, betslips = pagy(betslips, items: 20)

		@pagy, @records = pagy(:offset, betslips)

		slips = @records.as_json(only: [:id, :stake, :win_amount, :status, :created_at , :result, :payout],
												include: {
													 bets: { only: [:id, :fixture_id, :market_identifier, :odds, :outcome, :specifier, :outcome_desc, :bet_type, :created_at] } 
												}
											)
		
		render json: {
			current_page: @pagy.page,
			total_pages: @pagy.pages,
			total_count: @pagy.count,
			betslips: slips
		}

	end

	def show
			betslip = @current_user.bet_slips.find_by(id: params[:id])
			if betslip
					render json: betslip.as_json(only: [:id, :stake, :odds, :win_amount, :status, :created_at, :result, :payout],
																			include: {
																					bets: { only: [:id, :fixture_id, :market_identifier, :odds, :outcome, :specifier, :outcome_desc, :bet_type, :created_at]  } 
																			}
																	)
			else
					render json: { error: 'Bet slip not found' }, status: :not_found
			end
	end

	def create
		stake = params[:stake]
		bets_data = params[:bets] || []

		if stake.to_f < 1 || stake.to_f > 4000000
			render json: {message: "Amount should be between 1 UGX and 4,000,000 UGX"}, status: 400
			return
		end

		if stake.to_f > @current_user.balance
			# insufficient balance and return error
			render json: {message: "Insufficient balance"}, status: 400
			return
		end

		bet_slip = @current_user.bet_slips.build(stake: stake)

		pre_markets_data, live_markets_data = load_odds_data(bets_data)

		bets_arr = []

		bets_data.each do |bet_data|
      fixture_id = bet_data[:fixture_id]&.to_i
      market_identifier = bet_data[:market_identifier]&.to_s
      specifier = bet_data[:specifier].presence
      outcome_id = bet_data[:outcome_id]&.to_i
      bet_type = bet_data[:bet_type]
      outcome_desc = bet_data[:outcome]&.to_s

      if bet_type == 'PreMatch'
        odds = pre_markets_data.dig(fixture_id, market_identifier, specifier) || {}
      else
        odds = live_markets_data.dig(fixture_id, market_identifier, specifier) || {}
      end

      odd_entry = odds.values.find { |v| v["outcome_id"]&.to_i == outcome_id&.to_i }
      current_odds = odd_entry ? odd_entry["odd"] : nil

      if current_odds.nil? || current_odds == 0.0
        render json: {message: "One of the bets has changed odds or is no longer available. Please review your bet and try again."}, status: 400
        return
      end

      bets_arr << {
        user_id: @current_user.id,
        bet_slip: bet_slip,
        fixture_id: fixture_id,
        market_identifier: market_identifier,
        odds: current_odds,
        outcome_desc: outcome_desc,
        outcome: outcome_id,
        specifier: specifier,
        status: 'Active',
        bet_type: bet_type
      }
    end

		odds_arr = bets_arr.map { |x| x[:odds].to_f }
		total_odds = odds_arr.inject(:*).round(2)
		win_amount = (stake.to_f * total_odds.to_f).round(2)

		slip_bonus = SlipBonus.where('min_accumulator <= ? AND max_accumulator >= ?', bets_arr.count, bets_arr.count).where(status: 'Active')&.last

		if slip_bonus
			multiplier = slip_bonus.multiplier
			bonus_win = (win_amount.to_f * (multiplier.to_f / 100)).round(2)
		else
			bonus_win = 0.0
		end

		payout = (bonus_win.to_f + win_amount).round(2)
		tax = (bonus_win.to_f + win_amount) * 0.15

		BetSlip.transaction do
			# balance management
			previous_balance = @current_user.balance
			balance_after = @current_user.balance = (@current_user.balance - stake.to_f)
			@current_user.update!(balance: balance_after)

			# create the transaction
			@current_user.transactions.create!(
        balance_before: previous_balance,
        balance_after: balance_after,
        phone_number: @current_user.phone_number,
        status: 'SUCCESS',
        currency: 'UGX',
        amount: stake,
        category: 'Bet Stake'
      )

			# BetSlip and Bets creation
			bet_slip.assign_attributes(
        bet_count: bets_arr.count,
        stake: stake,
        odds: total_odds,
        status: 'Active',
        win_amount: win_amount,
        bonus: bonus_win,
        tax: tax,
        payout: payout
      )
      bet_slip.save!

			Bet.create!(bets_arr)

		end

		render json: {message: "Bet Slip created successfully", bet_slip_id: bet_slip.id}, status: 201
	end

	private

	def betslip_params
		params.require(:betslip).permit(:stake, bets_attributes: [:fixture_id, :market_identifier, :odd, :outcome, :outcome_id, :specifier, :bet_type])
	end

	def load_odds_data(bets_data)
    pre_match_criteria = []
    live_match_criteria = []

    bets_data.each do |bet|
      criteria = {
        fixture_id: bet[:fixture_id],
        market_identifier: bet[:market_identifier].to_s,
        specifier: bet[:specifier]
      }
      
      if bet[:bet_type] == 'PreMatch'
        pre_match_criteria << criteria
      else
        live_match_criteria << criteria
      end
    end

    # FIX: Safe querying without SQL injection
    pre_markets = fetch_markets_safely(PreMarket, pre_match_criteria)
    live_markets = fetch_markets_safely(LiveMarket, live_match_criteria)

    pre_markets_data = {}
    live_markets_data = {}

    pre_markets.each do |market|
      pre_markets_data[market.fixture_id] ||= {}
      pre_markets_data[market.fixture_id][market.market_identifier] ||= {}
      pre_markets_data[market.fixture_id][market.market_identifier][market.specifier] = market.odds
    end

    live_markets.each do |market|
      live_markets_data[market.fixture_id] ||= {}
      live_markets_data[market.fixture_id][market.market_identifier] ||= {}
      live_markets_data[market.fixture_id][market.market_identifier][market.specifier] = market.odds
    end

    return pre_markets_data, live_markets_data
	end

	def fetch_markets_safely(model_class, criteria_list)
    return [] if criteria_list.empty?

    fixture_ids = criteria_list.map { |c| c[:fixture_id] }.uniq
    candidates = model_class.where(fixture_id: fixture_ids)

    # This avoids complex/unsafe SQL OR clauses
    candidates.select do |market|
      criteria_list.any? do |c|
        market.fixture_id == c[:fixture_id].to_i &&
        market.market_identifier.to_s == c[:market_identifier].to_s &&
        market.specifier == c[:specifier]
      end
    end
	end
end