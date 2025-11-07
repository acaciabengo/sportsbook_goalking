class Backend::SlipBonusesController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"
  load_and_authorize_resource

  def index
    @slip_bonuses = SlipBonus.all.order("created_at DESC")
  end

  def new
    @slip_bonus = SlipBonus.new()
  end

  def create
    @slip_bonus = SlipBonus.new(slip_bonus_params.merge(status: "Active"))

    if @slip_bonus.save
      redirect_to backend_slip_bonuses_path
      flash[:notice] = "Slip Bonus Successfully Created."
    else
      flash[:alert] = @slip_bonus.errors
      redirect_to new_backend_slip_bonus_path
    end
  end

  private

  def slip_bonus_params
    params.require(:slip_bonus).permit(
      :multiplier,
      :expiry,
      :min_accumulator,
      :max_accumulator
    )
  end
end
