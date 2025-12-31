class AddMetaDataToBet < ActiveRecord::Migration[7.2]
  def change
    add_column :bets, :meta_data, :jsonb, default: {}
  end
end
