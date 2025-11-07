class CreateSports < ActiveRecord::Migration[7.2]
  def change
    create_table :sports do |t|
      t.integer :ext_sport_id, index: true
      t.string :name, index: true

      t.timestamps
    end
  end
end
