class CreateComplaints < ActiveRecord::Migration[7.0]
  def change
    create_table :complaints do |t|
      t.bigint :user_id
      t.string :category
      t.string :sub_category
      t.bigint :bet_id
      t.bigint :betslip_id
      t.decimal :transaction_amount, precision: 12, scale: 2
      t.date :transaction_date
      t.string :subject
      t.text :description
      t.string :preferred_contact_method
      t.string :status, default: 'pending'

      t.timestamps
    end

    add_index :complaints, :category
    add_index :complaints, :status
    add_index :complaints, :bet_id
    add_index :complaints, :betslip_id
  end
end
