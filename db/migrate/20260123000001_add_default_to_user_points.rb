class AddDefaultToUserPoints < ActiveRecord::Migration[7.2]
  def up
    # Update existing users with nil points to 0
    User.where(points: nil).update_all(points: 0)

    # Add default value for future users
    change_column_default :users, :points, 0
  end

  def down
    change_column_default :users, :points, nil
  end
end
