class ChangeMarketColumns < ActiveRecord::Migration[7.2]
  def change
    rename_column :markets, :description, :name
    add_column :markets,
               :sport_id,
               :references,
               foreign_key: {
                 to_table: :sports
               },
               index: true
  end
end
