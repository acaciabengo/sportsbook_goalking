module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # identified_by :current_user

    # def connect
    #   self.current_user = find_verified_user
    # end

    # private

    # def find_verified_user
    #   # read the token from the headers
    #   auth_header = request.headers['Authorization']
    #   token = auth_header&.split(' ')&.last if auth_header.present?

    #   return reject_unauthorized_connection unless token

    #   begin
    #     decoded_token = JWT.decode(token, ENV['DEVISE_JWT_SECRET_KEY'], true, algorithm: 'HS256')
    #     payload = decoded_token.first

    #     verified_user = User.find_by(id: payload['sub'])

    #     if verified_user
    #       return verified_user
    #     else
    #       reject_unauthorized_connection
    #     end
    #   rescue JWT::DecodeError, JWT::ExpiredSignature
    #     reject_unauthorized_connection
    #   end
    # end
  end
end

# Removed authentication to allow public access to channels because it's listed before authentication
# restrict by domain later
