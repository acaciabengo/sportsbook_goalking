class ChangeMarketIdToExtMarketId < ActiveRecord::Migration[7.2]
  def change
    rename_column :markets, :market_id, :ext_market_id
  end
end
