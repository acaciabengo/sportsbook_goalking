class Backend::VoidReasonsController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    @void_reasons = VoidReason.all.order("created_at DESC").page params[:page]
  end
end
