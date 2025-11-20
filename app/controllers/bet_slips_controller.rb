class BetSlipsController < ApplicationController
  before_action :authenticate_user!
  include CurrentCart
  before_action :set_cart

  def index; end

  def create
    cart_id = bet_slips_params[:cart_id]
    @cart = Cart.find(cart_id)

    stake = bet_slips_params[:stake].to_f

    #First check if stake is with in the limits
    if stake > 4000000 || stake < 1
      render json: {message: "Amount should be between 1 UGX and 4,000,000 UGX"}, status: 400
    end

    #check if the stake is present and contains only digits
    if bet_slips_params[:stake].present? &&
         bet_slips_params[:stake].scan(/\D/).empty?
      stake = bet_slips_params[:stake].to_f

      #check if there is sufficient balance
      if stake <= current_user.balance
        previous_balance = current_user.balance
        balance_after = current_user.balance = (current_user.balance - stake)
        transaction =
          current_user.transactions.build(
            balance_before: previous_balance,
            balance_after: balance_after,
            phone_number: current_user.phone_number,
            status: 'SUCCESS',
            currency: 'UGX',
            amount: stake,
            category: 'Bet Stake'
          )

        #declare empty array of bets
        bets_arr = []

        #create an empty betslip
        bet_slip = current_user.bet_slips.create!

        #create an array of bets
        @cart.line_bets.each do |bet|
          product = bet.market.include?('Pre') ? '3' : '1'
          market_id = bet.market_identifier.to_i #extract only the numbers in the market number
          if fetch_market_status(bet.market, bet.market_identifier, bet.fixture_id, bet.specifier) == 'Active'
            odd =
              fetch_current_odd(
                bet.market,
                bet.market_identifier,
                bet.fixture_id,
                bet.outcome,
                bet.specifier
              ).to_f
            specifier = bet.specifier
            bets_arr << {
              user_id: current_user.id,
              bet_slip_id: bet_slip.id,
              fixture_id: bet.fixture_id,
              market_identifier: market_id,
              outcome: bet.outcome,
              odds: odd,
              status: 'Active',
              product: product,
              outcome_desc: bet.description,
              specifier: specifier,
              sport: bet.sport
            }
          end
        end

        #initiate the betslip
        odds_arr = bets_arr.map { |x| x[:odds].to_f }
        total_odds = odds_arr.inject(:*).round(2)
        win_amount = (stake.to_f * total_odds.to_f)

        slip_bonus = SlipBonus.where('min_accumulator <= ? AND max_accumulator >= ?', bets_arr.count, bets_arr.count)

				if slip_bonus.exists? && slip_bonus.last.status == "Active"
					case bets_arr.count
						when (slip_bonus.last.min_accumulator)..(slip_bonus.last.max_accumulator)
							bonus_win = (slip_bonus.last.multiplier / 100) * win_amount
						else
							bonus_win = 0
					end
				else
					bonus_win = 0
				end

				payout = (bonus_win.to_f + win_amount)
        tax = (bonus_win.to_f + win_amount) * 0.15

        BetSlip.transaction do
          current_user.save!
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

        #process the betslips through MTS
        # if browser.device.mobile? || browser.device.tablet?
        #   channel = 'mobile'
        # else
        #   channel = 'internet'
        # end

        # begin
        # 	Mts::SubmitTicket.new.publish(slip_id: bet_slip.id, user_channel: channel, ip: request.remote_ip )
        # 	#run a worker in future to close this ticket if no reply is made
        # 	TicketMonitorWorker.perform_in(16.seconds, bet_slip.id)
        # rescue Exception => error
        # 	#fail the betslip and all the bets
        # 	#refund the user money
        # 	#consider a separate refund function, since it is called from three locations now 05/11/2020 Acacia
        # 	bet_slip.update!(status: "Failed")
        # 	bet_slip.bets.update_all(status: "Failed")
        # 	#refund the stake
        # 	previous_balance = current_user.balance
        # 	balance_after = current_user.balance = (current_user.balance + bet_slip.stake)
        # 	transaction = current_user.transactions.build(balance_before: previous_balance, balance_after: balance_after, phone_number: current_user.phone_number, status: "SUCCESS", currency: "UGX", amount: bet_slip.stake, category: "Refund" )

        # 	BetSlip.transaction do
        # 		current_user.save!
        # 		transaction.save!
        # 	end

        # 	#log the error
        # 	Rails.logger.error(error.message)
        # 	Rails.logger.error(error.backtrace.join("\n"))
        # end

        #delete the session and also delete the cart
        @cart.destroy if @cart.id == session[:cart_id]
        session[:cart_id] = nil

        #redirect to home page with a notification
        render json: { message: 'Thank You! Bets have been placed.', user: current_user }, status: 200
      else
        render json: {message: 'You have insufficient balance on your account. Please deposit some money.'}, status: 400
      end
    else
      render json: {message: 'Please add a correct stake amount'}, status: 400
      #redirect_to root_path, alert: "Please add a correct stake amount "
    end
  rescue Exception => error
    #log the error and redirect with an alert
    Rails.logger.error(error.message)
    Rails.logger.error(error.backtrace.join("\n"))
    render json: {message: 'Oops! Something went wrong.'}, status: 400
  end

  def update; end

  private

  def bet_slips_params
    params.require(:bet_slip).permit(:cart_id, :stake)
  end
 
end
