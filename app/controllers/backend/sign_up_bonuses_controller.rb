class Backend::SignUpBonusesController < ApplicationController
  before_action :authenticate_admin!

  layout "admin_application"
  load_and_authorize_resource

  def index
    @signup_bonuses = SignUpBonus.all.order("created_at DESC")
  end

  def new
    @signup_bonus = SignUpBonus.new()
  end

  def create
    @signup_bonus = SignUpBonus.new(sign_up_bonus_params)

    active_bonus = SignUpBonus.where(status: "Active")
    if active_bonus.blank?
      @signup_bonus.status = "Active"
    else
      flash[:alert] = "You already have an Active Bonus."
      render action: "new"
      return
    end

    if @signup_bonus.save!
      redirect_to backend_sign_up_bonuses_path
      flash[:notice] = "Signup Bonus Successfully Created."
    else
      flash[:alert] = @signup_bonus.errors
      redirect_to new_backend_sign_up_bonus_path
    end
  end

  private

  def sign_up_bonus_params
    params.require(:sign_up_bonus).permit(:amount, :expiry)
  end
end
