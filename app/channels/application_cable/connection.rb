module ApplicationCable
  class Connection < ActionCable::Connection::Base

    identified_by :current_user

    def connect
      self.current_user = current_user
    end

    private

    def current_user
      return @current_user if defined?(@current_user)

      auth_header = request.headers['Authorization']
      token = auth_header&.split(' ')&.last if auth_header.present?
      return @current_user = nil unless token

      begin
        decoded_token = JWT.decode(token, ENV['DEVISE_JWT_SECRET_KEY'], true, algorithm: 'HS256')
        payload = decoded_token.first
        @current_user = User.find_by(id: payload['sub'])
      rescue JWT::DecodeError, JWT::ExpiredSignature
        @current_user = nil
      end
    end
  end
end
