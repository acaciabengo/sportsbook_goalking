class Backend::TransactionsAnalyticsController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    authorize! :index,
               :transaction,
               message: "You are not authorized to view this page..."

    # write sql queries to extract withdraw and deposit amounts for the last 30 days
    
    withdraw_sql = <<-SQL
      SELECT
        DATE(created_at) AS date,
        SUM(amount) AS total_withdraw
      FROM transactions
      WHERE category = 'Withdraw'
        AND status IN ('COMPLETED', 'SUCCESS')
        AND created_at >= NOW() - INTERVAL '30 days'
      GROUP BY DATE(created_at)
      ORDER BY DATE(created_at);
    SQL

    deposit_sql = <<-SQL
      SELECT
        DATE(created_at) AS date,
        SUM(amount) AS total_deposit
      FROM transactions
      WHERE category ~ '^(Dep|Win)'
        AND status IN ('COMPLETED', 'SUCCESS')
        AND created_at >= NOW() - INTERVAL '30 days'
      GROUP BY DATE(created_at)
      ORDER BY DATE(created_at);
    SQL

    @withdraws = ActiveRecord::Base.connection.execute(withdraw_sql).to_a
    @deposits = ActiveRecord::Base.connection.execute(deposit_sql).to_a
    
  end
end
