class Complaint < ApplicationRecord
  

  # CATEGORIES = %w[betting transactions account technical other].freeze
  # CONTACT_METHODS = %w[phone email sms].freeze

  

  def self.ransackable_attributes(auth_object = nil)
    %w[
      user_id
      category
      sub_category
      bet_id
      betslip_id
      transaction_amount
      transaction_date
      subject
      description
      preferred_contact_method
      status
      created_at
      updated_at
    ]
  end
end
