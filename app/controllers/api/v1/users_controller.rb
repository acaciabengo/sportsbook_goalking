class Api::V1::UsersController < Api::V1::BaseController

  before_action :auth_user

  def show
    user = @current_user.as_json(only: [:id, :first_name, :last_name, :phone_number, :balance, :points, :created_at],
                                                      include: { user_bonuses: { only: [:id, :amount, :status, :expires_at, :created_at] } })
    user[:balance ] = user[:balance].to_f
    render json: { 
        user: user
      }, status: :ok
  end

  def update
    if @current_user.update(user_params)
      render json: { message: 'User updated successfully' }, status: :ok
    else
      render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def bonuses
    user_bonuses = @current_user.user_bonuses.where('expires_at > ?', Time.now).order(created_at: :desc)
    render json: { user_bonuses: user_bonuses.as_json(only: [:id, :amount, :expires_at, :created_at]) }, status: :ok
  end

  def redeem
    user = @current_user
    if user.points >= 120
      # create a user bonus and for each 120 points redeemed, give a bonus of 10000
      redeemable_points = (user.points / 120)&.to_i  * 120
      bonus_amount = (redeemable_points / 120) * 10000
      expiration_days = ENV['USER_BONUS_EXPIRATION_DAYS'].to_i || 3
      ActiveRecord::Base.transaction do
        expiration_date = Time.now() + expiration_days.days
        previous_points = user.points
        user.points = user.points - redeemable_points
        user.save!
        user.user_bonuses.create!(amount: bonus_amount, status: "Active", expires_at: expiration_date)
      end

      # render success response
      render json: {status: 200, message: 'Success'}
    else
      render json: { error: 'Insufficient points to redeem' }, status: :unprocessable_entity
    end

  end

  private
  def user_params
    params.permit(:password, :password_confirmation, :first_name, :last_name)
  end
end
