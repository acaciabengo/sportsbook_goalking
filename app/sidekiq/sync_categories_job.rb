class SyncCategoriesJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform(*args)
    sports_ids = Sport.all.pluck(:id, :ext_sport_id)
    # print("found #{sports_ids.size} sports to sync categories for\n")

    bet_balancer = BetBalancer.new

    sports_ids.each do |sport_id, ext_sport_id|
      categories_data = bet_balancer.get_categories(sport_id: ext_sport_id)

      categories_data
        .xpath("//Category")
        .each do |category|
          ext_category_id = category["BetbalancerCategoryID"].to_i
          category_name =
            category.at_xpath("Texts/Text[@Language='en']/Value")&.text

          next unless category_name.present?

          existing_category =
            Category.find_by(
              ext_category_id: ext_category_id,
              sport_id: sport_id
            )

          if existing_category
            # Only update if name has changed
            if existing_category.name != category_name
              unless existing_category.update(name: category_name)
                Rails.logger.error(
                  "Failed to update category #{existing_category.id}: #{existing_category.errors.full_messages.join(", ")}"
                )
              end
            end
          else
            # Use sport: to set the association, not sport_id:
            new_category =
              Category.create(
                ext_category_id: ext_category_id,
                name: category_name,
                sport: Sport.find(sport_id)
              )

            unless new_category.persisted?
              Rails.logger.error(
                "Failed to create category with external ID #{ext_category_id}: #{new_category.errors.full_messages.join(", ")}"
              )
            end
          end
        end
    end
  end
end
