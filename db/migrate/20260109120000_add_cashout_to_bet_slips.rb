class AddCashoutToBetSlips < ActiveRecord::Migration[7.0]
  def change
    add_column :bet_slips, :cashout_value, :decimal, precision: 10, scale: 2
    add_column :bet_slips, :cashout_at, :datetime

    add_index :bet_slips, :cashout_at
  end
end
