class Backend::MatchStatusesController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    @match_statuses =
      MatchStatus.all.order("created_at DESC").page params[:page]
  end
end
