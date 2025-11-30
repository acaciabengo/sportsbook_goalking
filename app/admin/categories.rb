ActiveAdmin.register Category do
  # Specify parameters which should be permitted for assignment
  permit_params :ext_category_id, :sport_id, :name

  # or consider:
  #
  # permit_params do
  #   permitted = [:ext_category_id, :sport_id, :name]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  # For security, limit the actions that should be available
  actions :all, except: []

  # Add or remove filters to toggle their visibility
  filter :id
  filter :ext_category
  filter :sport
  filter :name
  filter :created_at
  filter :updated_at

  # Add or remove columns to toggle their visibility in the index action
  index do
    selectable_column
    id_column
    column :ext_category
    column :sport
    column :name
    column :created_at
    column :updated_at
    actions
  end

  # Add or remove rows to toggle their visibility in the show action
  show do
    attributes_table_for(resource) do
      row :id
      row :ext_category
      row :sport
      row :name
      row :created_at
      row :updated_at
    end
  end

  # Add or remove fields to toggle their visibility in the form
  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs do
      f.input :ext_category
      f.input :sport
      f.input :name
    end
    f.actions
  end
end
