class SyncTournamentsJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform(*args)
    bet_balancer = BetBalancer.new

    Category.all.each do |category|
      tournaments_data =
        bet_balancer.get_tournaments(category_id: category.ext_category_id)

      tournaments_data
        .xpath("//Category/Tournament")
        .each do |tournament|
          tournament_id = tournament["BetbalancerTournamentID"].to_i
          tournament_name =
            tournament.at_xpath("Texts/Text[@Language='en']/Value").content

          if Tournament.exists?(
               ext_tournament_id: tournament_id,
               category: category
             )
            existing_tournament =
              Tournament.find_by(
                ext_tournament_id: tournament_id,
                category: category
              )
            if existing_tournament.name != tournament_name
              unless existing_tournament.update(name: tournament_name)
                Rails.logger.error(
                  "Failed to update tournament ##{existing_tournament.id}: #{existing_tournament.errors.full_messages.join(", ")}"
                )
              end
            end
          else
            new_tournament =
              Tournament.create(
                ext_tournament_id: tournament_id,
                name: tournament_name,
                category: category
              )

            unless new_tournament.persisted?
              Rails.logger.error(
                "Failed to create tournament: #{new_tournament.errors.full_messages.join(", ")}"
              )
            end
          end
        end
    end
  end
end
