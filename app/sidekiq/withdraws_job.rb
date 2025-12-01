class WithdrawsJob
  include Sidekiq::Job
  sidekiq_options queue: "high"
  sidekiq_options retry: false

  def perform(transaction_id)
    transaction = Transaction.find(transaction_id)
    user = transaction.user

    resource_id = generate_resource_id()
    withdraw = Withdraw.create(
      transaction_id: transaction.id,
      resource_id: resource_id,
      amount: transaction.amount,
      phone_number: transaction.phone_number,
      status: "PENDING",
      currency: "UGX",
      payment_method: "Mobile Money",
      balance_before: user.balance,
      user_id: transaction.user_id,
      transaction_reference: transaction.reference
    )

    if !withdraw.persisted?
      Rails.logger.error("Failed to create withdraw record for transaction #{transaction.id}")
      return
    end

    # execute withdraw logic here (e.g., call external API)
    client = Relworks.new()
    status, response = client.make_payment(
      msisdn: transaction.phone_number,
      amount: transaction.amount,
      description: "Withdrawal - #{transaction.reference}"
    )

    if status == 200 && response["success"] == true
      Withdraw.transaction do
        withdraw.update(
        status: "COMPLETED",
        ext_transaction_id: response["internal_reference"],
        balance_after: user.balance - transaction.amount,
        message: "Withdrawal successful"
      )

      # Update user balance
      user.update(balance: user.balance - transaction.amount)

      # Update transaction status
      transaction.update(status: "COMPLETED")
      end
      
    else
      withdraw.update(
        status: "FAILED",
        message: response["message"] || "Withdrawal failed"
      )

      # Update transaction status
      transaction.update(status: "FAILED")
    end
  end

  def generate_resource_id()
    loop do
      resource_id = SecureRandom.uuid
      break resource_id = resource_id unless Withdraw.where(resource_id: resource_id).exists?
    end
  end
end
