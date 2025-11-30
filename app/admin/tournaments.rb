ActiveAdmin.register Tournament do
  # Specify parameters which should be permitted for assignment
  permit_params :category_id, :ext_tournament_id, :name, :"#<ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition"

  # or consider:
  #
  # permit_params do
  #   permitted = [:category_id, :ext_tournament_id, :name, :"#<ActiveRecord::ConnectionAdapters::PostgreSQL::TableDefinition"]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  # For security, limit the actions that should be available
  actions :all, except: []

  # Add or remove filters to toggle their visibility
  filter :id
  filter :category
  filter :ext_tournament
  filter :created_at
  filter :updated_at
  filter :name
  

  # Add or remove columns to toggle their visibility in the index action
  index do
    selectable_column
    id_column
    column :category
    column :ext_tournament
    column :created_at
    column :updated_at
    column :name
    
    actions
  end

  # Add or remove rows to toggle their visibility in the show action
  show do
    attributes_table_for(resource) do
      row :id
      row :category
      row :ext_tournament
      row :created_at
      row :updated_at
      row :name
    end
  end

  # Add or remove fields to toggle their visibility in the form
  form do |f|
    f.semantic_errors(*f.object.errors.attribute_names)
    f.inputs do
      f.input :category
      f.input :ext_tournament
      f.input :name
    end
    f.actions
  end
end
