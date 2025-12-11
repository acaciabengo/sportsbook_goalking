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

    sports_data.xpath("//Sports/Sport").each do |sport_node|
      ext_sport_id = sport_node["BetbalancerSportID"].to_i
      
      # Extract name safely
      sport_name = sport_node.at_xpath("Texts/Text[@Language='en']/Value")&.text

      # Skip if ID is invalid (0 or nil converted to 0) or name is missing
      next unless ext_sport_id > 0 && sport_name.present?

      # Use find_or_initialize_by to prevent duplicates and handle updates cleanly
      sport = Sport.find_or_initialize_by(ext_sport_id: ext_sport_id)

      if sport.new_record? || sport.name != sport_name
        sport.name = sport_name
        unless sport.save
          Rails.logger.error(
            "Failed to save Sport ID #{ext_sport_id}: #{sport.errors.full_messages.join(", ")}"
          )
        end
      end
    end
  end
end
