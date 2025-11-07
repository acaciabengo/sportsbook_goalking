class CreateTournaments < ActiveRecord::Migration[7.2]
  def change
    create_table :tournaments do |t|
      t.references :category, null: false, foreign_key: true, index: true
      t.integer :ext_tournament_id, index: true
      t.string :name, t.timestamps
    end
  end
end
