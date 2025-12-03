class AddBetTypeToBet < ActiveRecord::Migration[7.2]
  def change
    add_column :bets, :bet_type, :string
  end
end
