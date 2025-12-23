class Backend::BetsController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"

  def index
    @q = Bet.includes(:fixture).ransack(params[:q])
    @bets = @q.result.order("created_at DESC").page params[:page]
  end
end
