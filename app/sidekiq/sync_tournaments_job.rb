class SyncTournamentsJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform(*args)
    bet_balancer = BetBalancer.new

    Category.each do |category|
      tournaments_data =
        bet_balancer.get_tournaments(category_id: category.ext_category_id)

      tournaments_data
        .xpath("//category")
        .each do |tournament|
          tournament_id = tournament["BetbalancerTournamentID"].to_i
          tournament_name =
            tournament.at_xpath("Text[@Language='en']/Value").content

          if Tournament.exists?(external_id: tournament_id, category: category)
            existing_tournament =
              Tournament.find_by(external_id: tournament_id, category: category)
            if existing_tournament.name != tournament_name
              existing_tournament.update(name: tournament_name)
            end
          else
            Tournament.create(
              ext_tournament_id: tournament_id,
              name: tournament_name,
              category: category
            )
          end
        end
    end
  end
end
