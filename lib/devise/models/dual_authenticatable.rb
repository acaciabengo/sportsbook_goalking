# frozen_string_literal: true

require 'devise/strategies/dual_authenticatable'

module Devise
  module Models
    module DualAuthenticatable
      extend ActiveSupport::Concern

      # TODO: Add any model-level methods needed for your authentication logic
      #
      # Example class methods:
      #   module ClassMethods
      #     def find_for_dual_authentication(conditions)
      #       find_for_authentication(conditions)
      #     end
      #   end
      #
      # Example instance methods:
      #   def valid_for_dual_authentication?(password)
      #     valid_password?(password)
      #   end

      included do
        # Add any callbacks or validations here
      end

      module ClassMethods
        # Add class methods here
      end
    end
  end
end
