module ApplicationCable
  class Connection < ActionCable::Connection::Base

    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      Rails.logger.info "ActionCable connected: #{current_user&.id || 'guest'}"
    end

    def receive(data)
      Rails.logger.info "RAW DATA RECEIVED: #{data.inspect}"
      super
    end

    private

    def find_verified_user
      auth_header = request.headers['Authorization']
      token = auth_header&.split(' ')&.last if auth_header.present?
      return nil unless token

      begin
        decoded_token = JWT.decode(token, ENV['DEVISE_JWT_SECRET_KEY'], true, algorithm: 'HS256')
        payload = decoded_token.first
        user = User.find_by(id: payload['sub'])
        user
      rescue JWT::DecodeError, JWT::ExpiredSignature => e
        Rails.logger.error "JWT Error: #{e.message}"
        nil
      end
    end
  end
end
