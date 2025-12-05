class Api::V1::TransactionsController < Api::V1::BaseController
  skip_before_action :verify_authenticity_token
  before_action :auth_user

  def index
    transactions = @current_user.transactions.all.order(created_at: :desc)
    @pagy, @records = pagy(:offset, transactions)

    render json: {
      current_page: @pagy.page,
      total_pages: @pagy.pages,
      total_count: @pagy.count,
      transactions: @records.as_json(only: [:id, :amount, :category, :balance_before, :balance_after, :created_at, :description])
    }
  end

  def deposit
    # accept phone number and amount
    amount = transaction_params[:amount].to_f
    # description = transaction_params[:description] || "Account Deposit"
    phone_number = transaction_params[:phone_number] || @current_user.phone_number

    if amount <= 0
      render json: {
          message: 'Deposit amount must be greater than zero.'
        },
        status: 400
      return
    end

    ext_reference = generate_reference
    
    transaction =
      Transaction.new(
        reference: ext_reference,
        amount: amount,
        phone_number: phone_number,
        category: 'Deposit',
        status: 'PENDING',
        currency: 'UGX',
        user_id: current_user.id
      )
    if transaction.save
      DepositsJob.perform_async(transaction.id)
      render json: {
               message: 'Please wait while we process your transaction...'
             },status: 200
    else
      Rails.logger.error("Transaction for user #{current_user.id} with reference #{transaction.reference} failed to save for user #{current_user.id}")
      render json: {
               message: 'Transaction Has failed please try again.'
             },
             status: 400
    end
  end

  def withdraw
    # accept phone number and amount
    amount = transaction_params[:amount].to_f
    # description = transaction_params[:description] || "Account Withdrawal"
    phone_number = transaction_params[:phone_number] || @current_user.phone_number

    # reject if withdrawal amount is negative or zero
    if amount <= 0
      render json: {
          message: 'Withdrawal amount must be greater than zero.'
        },
        status: 400
      return
    end
    

    if current_user.deposits.any?
      if amount > current_user.balance
        Rails.logger.error("Insufficient balance for withdrawal by user #{current_user.id}")
        render json: {
            message: 'Insufficient balance for this withdrawal.'
          },
          status: 400
        return
      end

      ext_reference = generate_reference
      transaction = Transaction.new(
          reference: ext_reference,
          amount: amount,
          phone_number: phone_number,
          category: 'Withdraw',
          status: 'PENDING',
          currency: 'UGX',
          user_id: current_user.id
        )

      if transaction.save
        WithdrawsJob.perform_async(transaction.id)
        render json: {
            message: 'Please wait while we process your withdrawal...'
          },
          status: 200
        return
      else
        Rails.logger.error("Transaction for withdrawal by user #{current_user.id} with reference #{transaction.reference} failed to save")
        render json: {
            message: 'Transaction has failed, please try again.'
          },
          status: 400
        return
      end
      
    else
      Rails.logger.error("User #{current_user.id} attempted withdrawal without prior deposits")
      render json: {
          message: 'You must have made at least one deposit before making a withdrawal.'
        },
        status: 400
      return
    end
  end

  private

  def generate_reference
    loop do
      reference = SecureRandom.uuid
      break reference = reference unless Transaction.where(reference: reference)
        .exists?
    end
  end

  def transaction_params
    params.permit(:amount, :phone_number)
  end
end
