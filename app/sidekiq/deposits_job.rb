class DepositsJob
  include Sidekiq::Job
  sidekiq_options queue: "high"
  sidekiq_options retry: false

  def perform(transaction_id)
    transaction = Transaction.find(transaction_id)
    user = transaction.user

    resource_id = generate_resource_id()

    deposit = Deposit.create!(
      transaction_id: transaction.id,
      resource_id: resource_id,
      amount: transaction.amount,
      phone_number: transaction.phone_number,
      status: "PENDING",
      currency: "UGX",
      payment_method: "Mobile Money",
      user_id: transaction.user_id,
      transaction_reference: transaction.reference,
      balance_before: user.balance
    )

    if !deposit.persisted?
      Rails.logger.error("Failed to create deposit record for transaction #{transaction.id}")
      return
    end

    client = Relworks.new()
    status, response = client.request_payment(
      msisdn: transaction.phone_number,
      amount: transaction.amount,
      description: "Deposit - #{transaction.reference}"
    )

    if status == 200 && response["success"] == true
      
      Deposit.transaction do
        deposit.update(
          status: "PENDING",
          ext_transaction_id: response["internal_reference"],
          message: "Deposit initiated",
        )

        # Update transaction status
        transaction.update(status: "PENDING")
      end
    else
      deposit.update(
        status: "FAILED",
        message: response["message"] || "Deposit failed"
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
