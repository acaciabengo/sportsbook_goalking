module SendSms
   require 'net/http'
   require 'uri'
   require "cgi"
   # require "httparty"

   def self.process_sms_now(receiver:, content:, sender_id:, args: {})

      if args[:append_to].present?
         content = content+args[:append_to]
      end

      content = CGI.escape(content)
      parameters = []
      parameters << "to=#{receiver}" if receiver.present?
      parameters << "message=#{content}" if content.present?
      parameters << "from=#{sender_id}" if sender_id.present?
      parameters << "token=#{ENV['TOKEN']}"
      message_params = parameters.join("&")
      message_url = "http://skylinesms.com/api/v2/json/messages?"+"#{message_params}"

      ##use net http
      uri = URI(message_url)
      request = Net::HTTP::Get.new(uri)
      response  = Net::HTTP.start(uri.host, uri.port) do |http|
        http.request(request)
      end

      if response.code == '200'
         return true
      else
         return false
      end
   rescue StandardError => e
      Rails.logger.error(e.message)
      false
   end
end
