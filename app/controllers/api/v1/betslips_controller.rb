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
		bets_data = params[:bets]

		if stake.to_f < 1 || stake.to_f > 4000000
			render json: {message: "Amount should be between 1 UGX and 4,000,000 UGX"}, status: 400
			return
		end

		if stake.to_f > @current_user.balance
			# insufficient balance and return error
			render json: {message: "Insufficient balance"}, status: 400
			return
		end

	 
		previous_balance = @current_user.balance
		balance_after = @current_user.balance = (@current_user.balance - stake.to_f)

		transaction =
			@current_user.transactions.build(
				balance_before: previous_balance,
				balance_after: balance_after,
				phone_number: @current_user.phone_number,
				status: 'SUCCESS',
				currency: 'UGX',
				amount: stake,
				category: 'Bet Stake'
			)
		

		bet_slip = @current_user.bet_slips.build(stake: stake)
		

		bets_arr = []

		bets_data.each do |bet_data|
			bets_arr << {
				user_id: @current_user.id,
				bet_slip: bet_slip,
				fixture_id: bet_data[:fixture_id],
				market_identifier: bet_data[:market_identifier],
				odds: bet_data[:odd],
				outcome_desc: bet_data[:outcome],
				outcome: bet_data[:outcome_id],
				specifier: bet_data[:specifier],
				status: 'Active',
				bet_type: bet_data[:bet_type]
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
			@current_user.save!
			transaction.save!
			Bet.create!(bets_arr)
			bet_slip.update!(
				bet_count: bets_arr.count,
				stake: stake,
				odds: total_odds,
				status: 'Active',
				win_amount: win_amount,
				bonus: bonus_win,
				tax: tax,
				payout: payout
			)
		end

		render json: {message: "Bet Slip created successfully", bet_slip_id: bet_slip.id}, status: 201
	end

	private

	def betslip_params
		params.require(:betslip).permit(:stake, bets_attributes: [:fixture_id, :market_id, :odd, :outcome, :outcome_id, :specifier, :bet_type])
	end
end
