class CreateCategories < ActiveRecord::Migration[7.2]
  def change
    create_table :categories do |t|
      t.integer :ext_category_id, index: true
      t.references :sport, null: false, foreign_key: true, index: true
      t.string :name

      t.timestamps
    end
  end
end
