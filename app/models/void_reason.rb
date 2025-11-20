class VoidReason < ApplicationRecord

   validates :description, presence: true
   validates :void_reason_id, presence: true
   validates :void_reason_id, uniqueness: true

   def self.ransackable_attributes(auth_object = nil)
      ["created_at", "description", "id", "updated_at", "void_reason_id"]
   end
end
