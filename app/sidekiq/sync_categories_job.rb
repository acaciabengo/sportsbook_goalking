class SyncCategoriesJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform(*args)
    bet_balancer = BetBalancer.new

    Sport.each do |sport|
      categories_data =
        bet_balancer.get_categories(sport_id: sport.ext_sport_id)

      categories_data
        .xpath("//sports/sport")
        .each do |category|
          category_id = category["BetbalancerCategoryID"].to_i
          category_name =
            category.at_xpath("Text[@Language='en']/Value").content

          if Category.exists?(external_id: category_id, sport: sport)
            existing_category =
              Category.find_by(external_id: category_id, sport: sport)
            if existing_category.name != category_name
              existing_category.update(name: category_name)
            end
          else
            Category.create(
              ext_category_id: category_id,
              name: category_name,
              sport: sport
            )
          end
        end
    end
  end
end
