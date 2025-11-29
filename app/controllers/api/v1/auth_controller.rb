class Api::V1::AuthController < Api::V1::BaseController
  # skip_before_action :authenticate_user!, only: [:login, :signup]

  def login
    phone_number = params[:phone_number]
    password = params[:password]

    # authenticate user with devise
    user = User.find_by(phone_number: phone_number)

    if user&.valid_password?(password)
      # Generate JWT token
      token = generate_jwt(user)
      
      render json: { 
        token: token, 
        user: user.as_json(only: [:id, :phone_number, :balance, :created_at]) 
      }, status: :ok
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end


  def signup
    phone_number = params[:phone_number]
    password = params[:password]
    password_confirmation = params[:password_confirmation]
    first_name = params[:first_name]
    last_name = params[:last_name]

    user = User.new(phone_number: phone_number, password: password, password_confirmation: password_confirmation, first_name: first_name, last_name: last_name)
    if user.save
      # Generate JWT token for new user
      token = generate_jwt(user)
      
      render json: { 
        token: token, 
        user: user.as_json(only: [:id, :phone_number, :balance, :created_at]) 
      }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def generate_jwt(user)
    JWT.encode(
      {
        sub: user.id,
        exp: 24.hours.from_now.to_i,
        iat: Time.now.to_i
      },
      ENV['DEVISE_JWT_SECRET_KEY'],
      'HS256'
    )
  end
end