class AddPerformanceIndexesForPreMatch < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Composite index for the main WHERE clause in pre_match queries
    # Covers: match_status = 'not_started' AND status IN ('0', 'active') AND start_date > NOW()
    add_index :fixtures, [:match_status, :status, :start_date],
              name: 'idx_fixtures_prematch_query',
              algorithm: :concurrently,
              if_not_exists: true

    # Index for tournament joins
    add_index :fixtures, :ext_tournament_id,
              name: 'idx_fixtures_ext_tournament_id',
              algorithm: :concurrently,
              if_not_exists: true

    # Index for category joins
    add_index :fixtures, :ext_category_id,
              name: 'idx_fixtures_ext_category_id',
              algorithm: :concurrently,
              if_not_exists: true

    # Composite index for pre_markets filtering
    # Covers: status IN ('active', '0') AND market_identifier = '1'
    add_index :pre_markets, [:status, :market_identifier],
              name: 'idx_pre_markets_status_market',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
