class Backend::TopupBonusesController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"
  load_and_authorize_resource

  def index
    @topup_bonuses = TopupBonus.all.order("created_at DESC")
  end

  def new
    @topup_bonus = TopupBonus.new()
  end

  def create
    @topup_bonus = TopupBonus.new(topup_bonus_params)

    status_active = TopupBonus.where(status: "Active")
    if !status_active.present?
      @topup_bonus.status = "Active"
    else
      flash[:alert] = "You already have an Active Bonus."
      render action: "new"
      return
    end

    if @topup_bonus.save!
      redirect_to backend_topup_bonuses_path
      flash[:notice] = "Topup Bonus Successfully Created."
    else
      flash[:alert] = @topup_bonus.errors
      redirect_to new_backend_topup_bonuse_path
    end
  end

  private

  def topup_bonus_params
    params.require(:topup_bonus).permit(:amount, :multiplier, :expiry)
  end
end
