ActiveAdmin.register BetRejection do
  menu parent: "Risk Management", priority: 1

  actions :index, :show

  filter :user_phone_number, as: :string, label: "Phone Number"
  filter :rejection_reason
  filter :bet_type
  filter :stake
  filter :potential_win
  filter :created_at

  scope :all, default: true
  scope :today
  scope :this_week

  index do
    selectable_column
    id_column
    column :user do |rejection|
      link_to rejection.user.phone_number, admin_user_path(rejection.user)
    end
    column :rejection_reason
    column :bet_type
    column :stake do |rejection|
      number_to_currency(rejection.stake, unit: "UGX ", precision: 0)
    end
    column :potential_win do |rejection|
      number_to_currency(rejection.potential_win, unit: "UGX ", precision: 0)
    end
    column :bet_count
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :id
      row :user do |rejection|
        link_to rejection.user.phone_number, admin_user_path(rejection.user)
      end
      row :rejection_reason
      row :bet_type
      row :stake do |rejection|
        number_to_currency(rejection.stake, unit: "UGX ", precision: 0)
      end
      row :potential_win do |rejection|
        number_to_currency(rejection.potential_win, unit: "UGX ", precision: 0)
      end
      row :bet_count
      row :created_at
      row :updated_at
    end

    panel "Bet Data" do
      if resource.bet_data.present?
        table_for resource.bet_data do
          column :fixture_id
          column :market_identifier
          column :specifier
          column :outcome_id
          column :odd
          column :bet_type
        end
      else
        para "No bet data available"
      end
    end

    panel "Metadata" do
      if resource.metadata.present?
        attributes_table_for resource.metadata do
          resource.metadata.each do |key, value|
            row(key) { value }
          end
        end
      else
        para "No metadata available"
      end
    end
  end

  sidebar "Rejection Statistics", only: :index do
    stats = BetRejection.group(:rejection_reason).count
    table_for stats do
      column("Reason") { |s| s[0] }
      column("Count") { |s| s[1] }
    end
  end
end
