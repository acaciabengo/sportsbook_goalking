class CreateBetRejections < ActiveRecord::Migration[7.2]
  def change
    create_table :bet_rejections do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :stake, precision: 15, scale: 2
      t.decimal :potential_win, precision: 15, scale: 2
      t.string :rejection_reason, null: false
      t.string :bet_type
      t.integer :bet_count
      t.jsonb :bet_data, default: []
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :bet_rejections, :rejection_reason
    add_index :bet_rejections, :bet_type
    add_index :bet_rejections, :created_at
    add_index :bet_rejections, [:user_id, :created_at]
  end
end
