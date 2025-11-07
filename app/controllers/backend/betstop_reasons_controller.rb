class Backend::BetstopReasonsController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    @betstop_reasons =
      BetstopReason.all.order("created_at DESC").page params[:page]
  end
end
