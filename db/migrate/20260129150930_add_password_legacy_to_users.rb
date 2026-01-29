class AddPasswordLegacyToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :legacy_password, :boolean, default: false
  end
end
