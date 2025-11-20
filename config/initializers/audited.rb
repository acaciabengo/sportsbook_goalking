require "audited"

Audited::Railtie.initializers.each(&:run)

Rails.application.config.to_prepare do
  if defined?(Audited::Audit)
    Audited::Audit.class_eval do
      def self.ransackable_attributes(auth_object = nil)
        ["action", "associated_id", "associated_type", "auditable_id", 
         "auditable_type", "audited_changes", "comment", "created_at", 
         "id", "remote_address", "request_uuid", "user_id", "user_type", 
         "username", "version"]
      end
    end
  end
end