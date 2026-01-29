# frozen_string_literal: true

require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class DualAuthenticatable < Authenticatable
      def valid?
        # Return true if this strategy should be tried
        true
      end

      def authenticate!
        # TODO: Implement your authentication logic here
        #
        # Available methods:
        #   - params: access request parameters
        #   - password: the password from params
        #   - authentication_hash: hash with authentication keys
        #   - mapping: the Devise mapping for current scope
        #
        # Use these to complete authentication:
        #   - success!(resource) - authentication succeeded
        #   - fail!(message) - authentication failed with message
        #   - fail(:invalid) - authentication failed with default invalid message
        #
        # Example:
        #   resource = mapping.to.find_for_authentication(authentication_hash)
        #   if resource && validate(resource) { resource.valid_password?(password) }
        #     success!(resource)
        #   else
        #     fail(:invalid)
        #   end

        fail(:invalid)
      end
    end
  end
end

Warden::Strategies.add(:dual_authenticatable, Devise::Strategies::DualAuthenticatable)
