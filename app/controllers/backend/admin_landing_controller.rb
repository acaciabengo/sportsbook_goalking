class Backend::AdminLandingController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    # write queries to extract bet stats for 30 days
    
    amounts_sql = <<-SQL
      SELECT
        DATE(created_at) AS date,
        SUM(stake) AS total_stake,
        SUM(CASE WHEN status = 'Closed' AND result = 'Win' THEN payout ELSE 0 END) AS total_amount_won,
        COUNT(*) AS total_bets
      FROM bet_slips
      WHERE created_at >= NOW() - INTERVAL '30 days'
      GROUP BY DATE(created_at)
      ORDER BY DATE(created_at);
    SQL

    counts_sql = <<-SQL
      SELECT
        DATE(created_at) AS date,
        COUNT(*) AS total_bets
      FROM bet_slips
      WHERE created_at >= NOW() - INTERVAL '30 days'
      GROUP BY DATE(created_at)
      ORDER BY DATE(created_at);
    SQL
    

    @amounts = ActiveRecord::Base.connection.execute(amounts_sql).to_a
    @counts = ActiveRecord::Base.connection.execute(counts_sql).to_a
  end
end
