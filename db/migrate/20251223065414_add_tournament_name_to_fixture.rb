class AddTournamentNameToFixture < ActiveRecord::Migration[7.2]
  def change
    add_column :fixtures, :tournament_name, :string
  end
end
