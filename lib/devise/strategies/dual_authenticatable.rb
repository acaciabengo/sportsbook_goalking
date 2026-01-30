# frozen_string_literal: true

require 'devise/strategies/authenticatable'
require_relative '../../dotnet_password_hasher'

module Devise
  module Strategies
    class DualAuthenticatable < Authenticatable
      def valid?
        # Return true if this strategy should be tried
        true
      end

      def authenticate!
        resource = mapping.to.find_for_authentication(authentication_hash)
        
        return fail(:not_found_in_database) unless resource

        if resource.legacy_password?
          # Verify .NET password
          if verify_dotnet_password(resource, password)
            # Migrate to bcrypt
            resource.password = password
            resource.legacy_password = false
            resource.save(validate: false)
            success!(resource)
          else
            fail(:invalid)
          end
        else
          # Use standard Devise bcrypt validation
          if resource.valid_password?(password)
            success!(resource)
          else
            fail(:invalid)
          end
        end
      end

      private

      def verify_dotnet_password(resource, plain_password)
        DotnetPasswordHasher.verify(plain_password, resource.encrypted_password)
      end

      def password
        params[scope][:password]
      end
    end
  end
end

Warden::Strategies.add(:dual_authenticatable, Devise::Strategies::DualAuthenticatable)
