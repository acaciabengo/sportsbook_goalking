class CreateCrownPointTransactions < ActiveRecord::Migration[7.2]
  def change
    create_table :crown_point_transactions do |t|
      t.references :bet_slip, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :points

      t.timestamps
    end
  end
end
