class ChangeMarketColumns < ActiveRecord::Migration[7.2]
  def change
    rename_column :markets, :description, :name
    add_reference :markets, :sport, null: false, foreign_key: true
  end
end
