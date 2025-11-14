class SyncSportsJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform()
    bet_balancer = BetBalancer.new
    status, sports_data = bet_balancer.get_sports

    if status != 200
      Rails.logger.error("Failed to fetch sports data: HTTP #{status}")
      return
    end

    # print the raw XML response for debugging
    # puts sports_data.to_xml

    sports_data
      .xpath("//Sports/Sport")
      .each do |sport|
        sport_id = sport["BetbalancerSportID"].to_i
        sport_name = sport.at_xpath("Texts/Text[@Language='en']/Value").content

        if Sport.exists?(ext_sport_id: sport_id)
          existing_sport = Sport.find_by(ext_sport_id: sport_id)
          if existing_sport.name != sport_name
            unless existing_sport.update(name: sport_name)
              Rails.logger.error(
                "Failed to update Sport ID #{sport_id}: #{existing_sport.errors.full_messages.join(", ")}"
              )
            end
          end
        else
          new_sport = Sport.create(ext_sport_id: sport_id, name: sport_name)
          if !new_sport.persisted?
            Rails.logger.error(
              "Failed to create Sport ID #{sport_id}: #{new_sport.errors.full_messages.join(", ")}"
            )
          end
        end
      end
  end
end
