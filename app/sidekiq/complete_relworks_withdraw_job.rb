class CompleteRelworksWithdrawJob
  include Sidekiq::Job
  sidekiq_options queue: "high"
  sidekiq_options retry: 3

  def perform(
    internal_reference:,
    status: nil,
    message: nil,
    customer_reference: nil,
    msisdn: nil,
    amount: nil,
    currency: nil,
    provider: nil,
    charge: nil,
    completed_at: nil
  )
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
        withdraw.update!(
          status: "COMPLETED",
          message: message || "Withdrawal successful",
          balance_after: withdraw.balance_before - withdraw.amount
        )

        transaction&.update!(status: "COMPLETED")
      end
    elsif status&.downcase == "failed"
      Withdraw.transaction do
        withdraw.update!(
          status: "FAILED",
          message: message || "Withdrawal failed"
        )

        # Refund balance on failed withdrawal
        user.update!(balance: user.balance + withdraw.amount&.to_f)

        transaction&.update!(status: "FAILED")
      end
    end
  end
end
