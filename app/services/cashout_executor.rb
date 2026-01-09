class CashoutExecutor
  attr_reader :error_message

  def initialize(bet_slip, user)
    @bet_slip = bet_slip
    @user = user
    @error_message = nil
  end

  def call
    # Get current cashout offer
    calculator = CashoutCalculator.new(@bet_slip)
    offer = calculator.call

    unless offer[:available]
      @error_message = offer[:reason] || 'Cashout not available'
      return false
    end

    cashout_value = offer[:cashout_value]

    # Execute cashout in a transaction
    ActiveRecord::Base.transaction do
      # Calculate tax on NET WINNINGS only (cashout_value - stake)
      net_winnings = cashout_value - @bet_slip.stake
      tax = net_winnings > 0 ? (net_winnings * BetSlip::TAX_RATE) : 0
      net_payout = cashout_value - tax

      # Update bet slip
      @bet_slip.update!(
        status: 'Closed',
        result: 'Win',
        cashout_value: cashout_value,
        cashout_at: Time.current,
        payout: net_payout,
        tax: tax
      )

      # Close all associated bets
      @bet_slip.bets.update_all(
        status: 'Closed',
        result: 'Win'
      )

      # Update user balance
      balance_before = @user.balance
      balance_after = balance_before + net_payout

      @user.update!(balance: balance_after)

      # Create transaction record
      @user.transactions.create!(
        balance_before: balance_before,
        balance_after: balance_after,
        phone_number: @user.phone_number,
        status: 'SUCCESS',
        currency: 'UGX',
        amount: net_payout,
        category: 'Cashout',
        reference: generate_reference
      )

      # Broadcast balance update via WebSocket
      ActionCable.server.broadcast("balance_#{@user.id}", {
        balance: balance_after,
        transaction: 'cashout',
        amount: net_payout
      })
    end

    true
  rescue StandardError => e
    @error_message = e.message
    Rails.logger.error("Cashout failed for bet_slip #{@bet_slip.id}: #{e.message}")
    false
  end

  private

  def generate_reference
    "CASHOUT-#{@bet_slip.id}-#{Time.current.to_i}"
  end
end
