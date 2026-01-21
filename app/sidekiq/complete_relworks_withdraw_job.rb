class CompleteRelworksWithdrawJob
  include Sidekiq::Job
  sidekiq_options queue: "high"
  sidekiq_options retry: 1

  def perform(internal_reference, status, message)
    withdraw = Withdraw.find_by(ext_transaction_id: internal_reference)

    if withdraw.nil?
      Rails.logger.error("Withdraw not found for internal_reference: #{internal_reference}")
      return
    end

    return if withdraw.status == "COMPLETED"

    user = withdraw.user
    transaction = Transaction.find_by(id: withdraw.transaction_id)

    if status&.downcase == "success"
      Withdraw.transaction do
        user.with_lock do
          user.decrement!(:balance, withdraw.amount.to_f)
        end

        withdraw.update!(
          status: "COMPLETED",
          message: message || "Withdrawal successful",
          balance_after: user.reload.balance
        )

        transaction&.update!(status: "COMPLETED")
      end
    elsif status&.downcase == "failed"
      Withdraw.transaction do
        withdraw.update!(
          status: "FAILED",
          message: message || "Withdrawal failed"
        )

        transaction&.update!(status: "FAILED")
      end
    end
  end
end
