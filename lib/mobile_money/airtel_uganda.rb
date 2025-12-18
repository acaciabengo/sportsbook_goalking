module MobileMoney
	class AirtelUganda

		require 'openssl'
		require 'json'
		require 'uri'
		require 'net/http'
		require 'logger'

		@@logger ||= Logger.new("#{Rails.root}/log/airtel_mobile_money.log")
		@@logger.level = Logger::ERROR

		##Deposit Account Credentials (Disbursements/Payouts)
		@@deposit_msisdn = ENV['AIRTEL_DEPOSIT_MSISDN']
		@@deposit_pin 	 = ENV['AIRTEL_DEPOSIT_PIN']

		##Withdraw Account Credentials (Collections)
		@@withdraw_username = ENV['AIRTEL_WITHDRAW_USERNAME']
		@@withdraw_password = ENV['AIRTEL_WITHDRAW_PASSWORD']
		@@withdraw_msisdn 	= ENV['AIRTEL_WITHDRAW_MSISDN']
		@@withdraw_billerID = ENV['AIRTEL_WITHDRAW_BILLERID']


		##Method to deposit money on user mobile phone / withdraw from user SB account / Disbursement
		def self.make_payments(phone_number, amount, transaction_id)
			phone_number = phone_number[3..-1]
			url = "http://172.27.77.145:9192/services/UTL"
			req_xml = "<?xml version='1.0' encoding='UTF-8'?><COMMAND><AMOUNT>#{amount}</AMOUNT><MSISDN2>#{phone_number}</MSISDN2><MSISDN>#{@@deposit_msisdn}</MSISDN><serviceType>MERCHCASHIN</serviceType><REFERENCE_NO>BETCITY</REFERENCE_NO><EXTTRID>#{transaction_id}</EXTTRID><interfaceId>BETCITY</interfaceId><PIN>#{@@deposit_pin}</PIN></COMMAND>"
			uri = URI.parse(url)
			http = Net::HTTP.new(uri.host, uri.port)
			http.read_timeout = 180
			request = Net::HTTP::Post.new(uri.request_uri)
			request.content_type = 'text/xml'
			request.body = req_xml
			# http.use_ssl = true
			# http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			http.set_debug_output($stdout)
			res = http.request(request)
			result = Hash.from_xml(res.body)
			if result.has_key?("COMMAND") && res.code == "200"
				return {ext_transaction_id: result['COMMAND']['TXNID'], status: result['COMMAND']['TXNSTATUS'] , message: result['COMMAND']['MESSAGE'] }
			else
				@@logger.error(result)
				return nil
			end

		rescue StandardError => e
			@@logger.error(e.message)
		end


		##Make to withdraw money from user mobile phone / Deposit on user SB Account / Collection
		def self.request_payments(phone_number, amount, transaction_id)
			message = "BETSB DEPOSIT"
			phone_number = phone_number[3..-1]
			url = "http://172.27.77.145:9192/services/UTL"
	  		req_xml = "<?xml version='1.0' encoding='UTF-8'?><COMMAND><interfaceId>BETCITY</interfaceId><MSISDN>#{phone_number}</MSISDN><MSISDN2>#{@@withdraw_msisdn}</MSISDN2><AMOUNT>#{amount}</AMOUNT><EXTTRID>#{transaction_id}</EXTTRID><REFERENCE>#{message}</REFERENCE><BILLERID>#{@@withdraw_billerID}</BILLERID><MEMO>#{message}</MEMO><serviceType>MERCHPAY</serviceType><USERNAME>#{@@withdraw_username}</USERNAME><PASSWORD>#{@@withdraw_password}</PASSWORD></COMMAND>"
			uri = URI.parse(url)
			http = Net::HTTP.new(uri.host, uri.port)
			http.read_timeout = 180
			request = Net::HTTP::Post.new(uri.request_uri)
			request.content_type = 'text/xml'
			request.body = req_xml
			# http.use_ssl = true
			# http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			http.set_debug_output($stdout)
			res = http.request(request)
			result = Hash.from_xml(res.body)
			if result.has_key?("COMMAND")  && res.code == "200"
				return {status: result['COMMAND']['TXNSTATUS'], message: result['COMMAND']['MESSAGE'] }
			else
				@@logger.error(result)
				return nil
			end
		rescue StandardError => e
			@@logger.error(e.message)
		end

		def self.check_transaction_status(ext_transaction_id)
			url = "http://172.27.77.145:9192/services/UTL"
			req_xml = "<?xml version='1.0' encoding='UTF-8'?><COMMAND><TYPE>TXNEQREQ</TYPE><interfaceId>BETCITY</interfaceId><EXTTRID>#{ext_transaction_id}</EXTTRID><TRID></TRID></COMMAND>"
			uri = URI.parse(url)
			http = Net::HTTP.new(uri.host, uri.port)
			request = Net::HTTP::Post.new(uri.request_uri)
			request.content_type = 'text/xml'
			request.body = req_xml
			# http.use_ssl = true
			# http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			http.set_debug_output($stdout)
			res = http.request(request)
			result = Hash.from_xml(res.body)
			if result.has_key?("COMMAND") && res.code == "200"
				return {status: result['COMMAND']['TXNSTATUS'], message: result['COMMAND']['MESSAGE'] }
			else
				@@logger.error(result)
				return nil
			end

		rescue StandardError => e
			@@logger.error(e.message)
		end

		def self.get_collection_balance
			url = "http://172.27.77.145:9192/services/UTL"
			req_xml = "<?xml version='1.0' encoding='UTF-8'?><COMMAND><BPROVIDER>101</BPROVIDER><PAYID1>12</PAYID1><PAYID2>12</PAYID2><PAYID>12</PAYID><PIN>#{@@withdraw_pin}</PIN><language>en</language><PROVIDER>101</PROVIDER><MSISDN>#{@@withdraw_msisdn}</MSISDN><TYPE>RBEREQ</TYPE></COMMAND>"
			uri = URI.parse(url)
			http = Net::HTTP.new(uri.host, uri.port)
			request = Net::HTTP::Post.new(uri.request_uri)
			request.content_type = 'text/xml'
			request.body = req_xml
			# http.use_ssl = true
			# http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			http.set_debug_output($stdout)
			res = http.request(request)
			result = Hash.from_xml(res.body)
			if result.has_key?("COMMAND") && result['COMMAND'].has_key?("BALANCE") && res.code == "200"
				return {amount: result['COMMAND']['BALANCE'], currency: "UGX", status: result['COMMAND']['TXNSTATUS'] }
			else
				@@logger.error(result)
				return nil
			end

		rescue StandardError => e
			@@logger.error(e.message)
		end

		def self.get_payout_balance
			url = "http://172.27.77.145:9192/services/UTL"
			req_xml = "<?xml version='1.0' encoding='UTF-8'?><COMMAND><BPROVIDER>101</BPROVIDER><PAYID1>12</PAYID1><PAYID2>12</PAYID2><PAYID>12</PAYID><PIN>#{@@deposit_pin}</PIN><language>en</language><PROVIDER>101</PROVIDER><MSISDN>#{@@deposit_msisdn}</MSISDN><TYPE>RBEREQ</TYPE></COMMAND>"
			uri = URI.parse(url)
			http = Net::HTTP.new(uri.host, uri.port)
			request = Net::HTTP::Post.new(uri.request_uri)
			request.content_type = 'text/xml'
			request.body = req_xml
			# http.use_ssl = true
			# http.verify_mode = OpenSSL::SSL::VERIFY_NONE
			http.set_debug_output($stdout)
			res = http.request(request)
			result = Hash.from_xml(res.body)
			if result.has_key?("COMMAND") && result['COMMAND'].has_key?("BALANCE") && res.code == "200"
				return {amount: result['COMMAND']['BALANCE'], currency: "UGX", status: result['COMMAND']['TXNSTATUS'] }
			else
				@@logger.error(result)
				return nil
			end

		rescue StandardError => e
			@@logger.error(e.message)
		end

	end

end
