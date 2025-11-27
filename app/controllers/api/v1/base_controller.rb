class Api::V1::BaseController < ApplicationController
  # Add a function called auth_user that does not conflict with Devise
  def auth_user
    #  Read the JWT token from the Authorization header
    auth_header = request.headers['Authorization']
    token = auth_header.split(' ').last if auth_header.present?

    begin
      # Decode the JWT token
      decoded_token = JWT.decode(token, Rails.application.credentials.devise_jwt_secret_key!, true, algorithm: 'HS256')
      payload = decoded_token.first

      # Find the user by ID from the payload
      @current_user = User.find_by(id: payload['sub'])

      unless @current_user
        render json: { error: 'User not found' }, status: :unauthorized
      end

    rescue JWT::DecodeError => e
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end
end
