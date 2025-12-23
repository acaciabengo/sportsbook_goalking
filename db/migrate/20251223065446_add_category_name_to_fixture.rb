class AddCategoryNameToFixture < ActiveRecord::Migration[7.2]
  def change
    add_column :fixtures, :category_name, :string
  end
end
