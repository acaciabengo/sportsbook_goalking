class SyncCategoriesJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 1

  def perform(*args)
    sports_ids = Sport.all.pluck(:id, :ext_sport_id)
    # print("found #{sports_ids.size} sports to sync categories for\n")

    bet_balancer = BetBalancer.new

    sports_ids.each do |sport_id, ext_sport_id|
      status, categories_data =
        bet_balancer.get_categories(sport_id: ext_sport_id)
      if status != 200
        Rails.logger.error("Failed to fetch categories data: HTTP #{status}")
        next
      end

      categories_data
        .xpath("//Category")
        .each do |category|
          ext_category_id = category["BetbalancerCategoryID"].to_i
          category_name =
            category.at_xpath("Texts/Text[@Language='en']/Value")&.text

          next unless category_name.present? && ext_category_id > 0

          category_record = Category.find_or_initialize_by(
            ext_category_id: ext_category_id,
            sport_id: sport_id
          )

          if category_record.new_record? || category_record.name != category_name
            category_record.name = category_name

            unless category_record.save
              Rails.logger.error(
                "Failed to save category #{ext_category_id}: #{category_record.errors.full_messages.join(", ")}"
              )
            end
          end
        end
    end
  end
end
