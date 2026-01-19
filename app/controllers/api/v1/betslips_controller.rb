class Api::V1::BetslipsController < Api::V1::BaseController
	skip_before_action :verify_authenticity_token
	before_action :auth_user

	def index
		betslips = @current_user.bet_slips.includes(bets: :fixture).order(created_at: :desc)
		@pagy, betslips = pagy(betslips, items: 20)

		@pagy, @records = pagy(:offset, betslips)

		slips = @records.as_json(only: [:id, :stake, :win_amount, :status, :created_at , :result, :payout],
												include: {
													 bets: {
														 only: [:id, :fixture_id, :market_identifier, :odds, :outcome, :specifier, :outcome_desc, :bet_type, :status, :result, :created_at],
														 methods: [:market_name],
														 include: {
															 fixture: { only: [:part_one_name, :part_two_name, :start_date] }
														 }
													 }
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
			betslip = @current_user.bet_slips.includes(bets: :fixture).find_by(id: params[:id])
			if betslip
					render json: betslip.as_json(only: [:id, :stake, :odds, :win_amount, :status, :created_at, :result, :payout],
																			include: {
																					bets: {
																						only: [:id, :fixture_id, :market_identifier, :odds, :outcome, :specifier, :outcome_desc, :bet_type, :created_at, :status, :result],
																						methods: [:market_name],
																						include: {
																							fixture: { only: [:part_one_name, :part_two_name, :start_date] }
																						}
																					}
																			}
																	)
			else
					render json: { error: 'Bet slip not found' }, status: :not_found
			end
	end

	def create
		service = BetslipCreator.new(@current_user, params)

		if service.call
			render json: { message: "Bet Slip created successfully", bet_slip_id: service.bet_slip.id }, status: 201
		else
			render json: { message: service.error_message }, status: 400
		end
	end

	def cashout_offer
		betslip = @current_user.bet_slips.find_by(id: params[:id])

		unless betslip
			render json: { error: 'Bet Slip not found' }, status: :not_found
			return
		end

		calculator = CashoutCalculator.new(betslip)
		offer = calculator.call

		render json: offer
	end

	def cashout
		betslip = @current_user.bet_slips.find_by(id: params[:id])

		unless betslip
			render json: { error: 'Bet slip not found' }, status: :not_found
			return
		end

		executor = CashoutExecutor.new(betslip, @current_user)

		if executor.call
			render json: {
				success: true,
				message: 'Bet cashed out successfully',
				cashout_value: betslip.cashout_value&.to_f,
				new_balance: @current_user.balance&.to_f
			}, status: :ok
		else
			render json: {
				success: false,
				error: executor.error_message
			}, status: :unprocessable_entity
		end
	end

	private

	def betslip_params
		params.require(:betslip).permit(:stake, bets_attributes: [:fixture_id, :market_identifier, :odd, :outcome, :outcome_id, :specifier, :bet_type, :bonus])
	end
end