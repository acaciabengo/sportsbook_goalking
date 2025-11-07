class AddStatusAndResultToBetSlips < ActiveRecord::Migration[7.2]
  def change
    add_column :bet_slips, :bet_slip_status, :string
    add_column :bet_slips, :bet_slip_result, :string
  end
end
