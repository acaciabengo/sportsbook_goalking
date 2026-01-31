# frozen_string_literal: true

require 'devise/strategies/dual_authenticatable'
require_relative '../../dotnet_password_hasher'

module Devise
  module Models
    module DualAuthenticatable
      extend ActiveSupport::Concern

      included do
        attr_reader :password, :current_password
        attr_accessor :password_confirmation
      end

      # Verifies password and migrates legacy .NET passwords to bcrypt
      def valid_password?(password)
        return false if encrypted_password.blank?

        if legacy_password?
          if DotnetPasswordHasher.verify(password, encrypted_password)
            # Migrate to bcrypt on successful login
            migrate_to_bcrypt!(password)
            true
          else
            false
          end
        else
          Devise::Encryptor.compare(self.class, encrypted_password, password)
        end
      end

      # Migrates legacy .NET password to bcrypt
      def migrate_to_bcrypt!(plain_password)
        new_hash = Devise::Encryptor.digest(self.class, plain_password)
        update_columns(
          encrypted_password: new_hash,
          legacy_password: false,
          updated_at: Time.current
        )
        Rails.logger.info("[DualAuth] Migrated user #{id} from .NET to bcrypt")
      rescue => e
        Rails.logger.error("[DualAuth] Failed to migrate user #{id}: #{e.message}")
      end

      # Sets password and hashes it with bcrypt
      def password=(new_password)
        @password = new_password
        self.encrypted_password = password_digest(new_password) if new_password.present?
      end

      # Generates bcrypt digest
      def password_digest(password)
        Devise::Encryptor.digest(self.class, password)
      end

      # Required by Devise for authentication
      def authenticatable_salt
        encrypted_password[0, 29] if encrypted_password
      end

      module ClassMethods
        def find_for_authentication(conditions)
          find_by(conditions)
        end

        Devise::Models.config(self, :pepper, :stretches)
      end
    end
  end
end
