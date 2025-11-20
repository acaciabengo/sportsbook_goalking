class Withdraw < ApplicationRecord
  audited

  belongs_to :user
   #Commented code is just a temporary change as we get fix
   validates :amount, presence: true
   #validates :network, presence: true
   validates :payment_method, presence: true
   validates :transaction_id, presence: true
   #validates :ext_transaction_id, presence: true
   validates :resource_id, presence: true
   validates :status, presence: true
   validates :currency, presence: true
   validates :phone_number, presence: true
   validates :phone_number, format: {with: /\A(256)\d{9}\z/}
   validates :transaction_id, uniqueness: true
   #validates :ext_transaction_id, uniqueness: true
   validates :resource_id, uniqueness: true

   def self.ransackable_associations(auth_object = nil)
      ["audits", "user"]
   end

   def self.ransackable_attributes(auth_object = nil)
      ["amount", "balance_after", "balance_before", "created_at", "currency", "ext_transaction_id", "id", "message", "network", "payment_method", "phone_number", "receiving_fri", "resource_id", "status", "transaction_id", "transaction_reference", "updated_at", "user_id"]
   end
   

   def self.to_csv

      CSV.generate(headers: true) do |csv|
         csv << column_names

         all.each do |withdraw|
            csv << withdraw.attributes.values_at(*column_names)
         end
      end
   end
end
