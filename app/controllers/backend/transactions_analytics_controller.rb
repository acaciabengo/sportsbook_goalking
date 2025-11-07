class Backend::TransactionsAnalyticsController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    authorize! :index,
               :transaction,
               message: "You are not authorized to view this page..."
    withdraws = []
    deposits = []
    labels = []

    #get withdraws and deposits from the last 21 days
    ((Date.today - 21)..Date.today).each do |date|
      ##Push dates to the dates array
      labels.push(date.to_s)

      ##Pull counts of the withdraws and deposits from the DB
      withdraw_amount =
        Transaction.where(
          "created_at >= ? and created_at <= ? and status = ? and category = ?",
          date.beginning_of_day,
          date.end_of_day,
          "SUCCESS",
          "Withdraw"
        ).sum(:amount)
      deposit_amount =
        Transaction.where(
          "created_at >= ? and created_at <= ? and status = ? and category ~* ?",
          date.beginning_of_day,
          date.end_of_day,
          "SUCCESS",
          "^(Dep|Win)"
        ).sum(:amount)

      ##Push the values to the data arrays
      withdraws.push(withdraw_amount)
      deposits.push(deposit_amount)
    end
    gon.labels = labels
    gon.withdraws = withdraws
    gon.deposits = deposits
  end
end
