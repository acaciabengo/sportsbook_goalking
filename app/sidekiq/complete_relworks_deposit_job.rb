class CompleteRelworksDepositJob
  include Sidekiq::Job
  sidekiq_options queue: "high"
  sidekiq_options retry: 1

  def perform(internal_reference, status, message)
    deposit = Deposit.find_by(ext_transaction_id: internal_reference)

    if deposit.nil?
      Rails.logger.error("Deposit not found for internal_reference: #{internal_reference}")
      return
    end

    return if deposit.status == "COMPLETED"

    user = deposit.user
    transaction = Transaction.find_by(id: deposit.transaction_id)

    if status&.downcase == "success"
      Deposit.transaction do
        user.with_lock do
          user.increment!(:balance, deposit.amount.to_f)
        end

        deposit.update!(
          status: "COMPLETED",
          message: message || "Deposit successful",
          balance_after: user.reload.balance
        )

        transaction&.update!(status: "COMPLETED")
      end
    elsif status&.downcase == "failed"
      deposit.update!(
        status: "FAILED",
        message: message || "Deposit failed"
      )

      transaction&.update!(status: "FAILED")
    end
  end
end
