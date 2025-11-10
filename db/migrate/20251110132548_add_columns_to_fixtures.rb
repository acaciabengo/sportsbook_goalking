class AddColumnsToFixtures < ActiveRecord::Migration[7.2]
  def change
    add_column :fixtures, :ext_category_id, :integer, null: false, default: 0
    add_column :fixtures, :ext_tournament_id, :integer, null: false, default: 0
  end
end
