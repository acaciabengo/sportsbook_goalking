class AddExpiresAtToUserBonus < ActiveRecord::Migration[7.2]
  def change
    add_column :user_bonuses, :expires_at, :datetime
  end
end
