class Api::V1::AuthController < Api::V1::BaseController
  def login
    phone_number = params[:phone_number]
    password = params[:password]

    # authenticate user with device
    user = User.find_by(phone_number: phone_number)

    if user&.valid_password?(password)
      token = encode_token(user_id: user.id)
      render json: { token: token, user: user }, status: :ok
    else
      render json: { error: 'Invalid credentials' }, status: :unauthorized
    end
  end


  def signup
    phone_number = params[:phone_number]
    password = params[:password]
    password_confirmation = params[:password_confirmation]

    user = User.new(phone_number: phone_number, password: password, password_confirmation: password_confirmation)
    if user.save
      token = encode_token(user_id: user.id)
      render json: { token: token, user: user }, status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def encode_token(payload)
    JWT.encode(payload, Rails.application.credentials.secret_key_base)
  end
end