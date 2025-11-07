class SyncSportsJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform()
    bet_balancer = BetBalancer.new
    sports_data = bet_balancer.get_sports

    sports_data
      .xpath("//sports")
      .each do |sport|
        sport_id = sport["BetbalancerSportID"].to_i
        sport_name = sport.at_xpath("/Text[@Language='en']/Value").content

        if Sport.exists?(external_id: sport_id)
          existing_sport = Sport.find_by(external_id: sport_id)
          if existing_sport.name != sport_name
            existing_sport.update(name: sport_name)
          end
        else
          Sport.create(external_id: sport_id, name: sport_name)
        end
      end
  end
end
