class Api::V1::UsersController < Api::V1::BaseController

  before_action :auth_user

  def show
    user = @current_user.as_json(only: [:id, :first_name, :last_name, :phone_number, :balance, :created_at])
    user[ :balance ] = user[:balance].to_f
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

  private
  def user_params
    params.permit(:password, :password_confirmation, :first_name, :last_name)
  end
end
