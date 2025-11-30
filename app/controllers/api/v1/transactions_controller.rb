class Api::V1::TransactionsController < ApplicationController
  before_action :auth_user

  def index
    transactions = @current_user.transactions.order(created_at: :desc)
    @pagy, transactions = pagy(transactions, items: 20)

    @pagy, @records = pagy(:offset, transactions)

    render json: {
      current_page: @pagy.page,
      total_pages: @pagy.pages,
      total_count: @pagy.count,
      transactions: @records.as_json(only: [:id, :amount, :transaction_type, :balance_before, :balance_after, :created_at, :description])
    }
  end

  def deposit
    # accept phone number and amount
    amount = transaction_params[:amount].to_f
    description = transaction_params[:description] || "Account Deposit"
    phone_number = transaction_params[:phone_number] || @current_user.phone_number
  end

  def withdraw
    # accept phone number and amount
    amount = transaction_params[:amount].to_f
    description = transaction_params[:description] || "Account Withdrawal"
    phone_number = transaction_params[:phone_number] || @current_user.phone_number
  end

  private

  def transaction_params
    params.permit(:amount, :transaction_type, :description)
  end
end
