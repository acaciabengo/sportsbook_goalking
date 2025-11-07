class SmsWorker
    include Sidekiq::Worker
    # include Sidekiq::Throttled::Worker
  
    sidekiq_options queue: "default"
    sidekiq_options retry: false
  
    require 'send_sms'
  
    # sidekiq_throttle({
    #    # Allow maximum 20 concurrent jobs of this class at a time.
    #    :concurrency => { :limit => 20 }
    # })
  
    def perform(phone_number, message, sender_id)
      sendSms.process_sms_now(receiver: phone_number, content: message, sender_id: sender_id)
    end
end
  