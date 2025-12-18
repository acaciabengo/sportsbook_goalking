module MobileMoney
    class AirtelOpenApi
        require 'openssl'
		require 'json'
		require 'uri'
		require 'net/http'
		require 'logger'
        require 'base64'

        @@base_url_staging = "https://openapiuat.airtel.africa"
        @@base_url_production = "https://openapi.airtel.africa"
        @@client_id = ENV["AIRTEL_CLIENT_ID"]
        @@client_secret = ENV["AIRTEL_CLIENT_SECRET"]
        @@pin = ENV["AIRTEL_PIN"]
        @@public_key = ENV["AIRTEL_PUBLIC_KEY"]

        def self.request_payments(amount, ext_reference, phone_number)

            token = get_auth_token()

            if token
                phone_number = format_number(phone_number)
                url = @@base_url_production + "/merchant/v1/payments/"

                uri = URI(url)

                req = Net::HTTP::Post.new(uri)

                ## Set the headers
                #set content-type
                req['Content-Type'] = "application/json"

                #set accept
                req['Accept'] = "*/*"
                #set token
                req['Authorization'] = "Bearer #{token}"
                
                #set country
                req['X-Country'] = "UG"

                #set currency
                req['X-Currency'] = "UGX"

                #Set request body
                request_body = {
                    reference: "GoalKing Deposit",
                    subscriber: {
                        msisdn: phone_number
                    },
                    transaction: {
                        amount: amount,
                        id: ext_reference
                    }
                }

                req.body = request_body.to_json

                res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|

                    http.request(req)

                end

                return JSON.parse(res.body)
            else
                return nil
            end
        end

        def self.check_collection_status(transaction_id)
            token = get_auth_token()

            if token
                url = @@base_url_production + "/standard/v1/payments/#{transaction_id}"

                uri = URI(url)

                req = Net::HTTP::Get.new(uri)

                ## Set the headers
                #set content-type
                req['Content-Type'] = "application/json"

                #set accept
                req['Accept'] = "*/*"
                #set token
                req['Authorization'] = "Bearer #{token}"
                
                #set country
                req['X-Country'] = "UG"

                #set currency
                req['X-Currency'] = "UGX"

                res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
                    http.request(req)
                end
                result = JSON.parse(res.body)
                return result
            else
                return nil
            end
        end

        def self.make_payments(amount, ext_reference, phone_number)
            token = get_auth_token()

            if token
                phone_number = format_number(phone_number)
                passcode = encrypt_pin()
                url = @@base_url_production + "/standard/v1/disbursements/"

                uri = URI(url)

                req = Net::HTTP::Post.new(uri)

                ## Set the headers
                #set content-type
                req['Content-Type'] = "application/json"

                #set accept
                req['Accept'] = "*/*"
                #set token
                req['Authorization'] = "Bearer #{token}"
                
                #set country
                req['X-Country'] = "UG"

                #set currency
                req['X-Currency'] = "UGX"

                # Set request body
                request_body = {
                    payee: {
                        msisdn: phone_number
                    },
                    reference: "Payment From GoalKing",
                    pin: passcode,
                    transaction: {
                        amount: amount,
                        id: ext_reference
                    }
                }

                req.body = request_body.to_json

                res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|

                    http.request(req)

                end

                return JSON.parse(res.body)
            else
                return nil
            end
        end

        def self.check_disbursement_status(transaction_id)
            token = get_auth_token()

            if token
                url = @@base_url_production + "/standard/v1/disbursements/#{transaction_id}"

                uri = URI(url)

                req = Net::HTTP::Get.new(uri)

                ## Set the headers
                #set content-type
                req['Content-Type'] = "application/json"

                #set accept
                req['Accept'] = "*/*"
                #set token
                req['Authorization'] = "Bearer #{token}"
                
                #set country
                req['X-Country'] = "UG"

                #set currency
                req['X-Currency'] = "UGX"

                res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
                    http.request(req)
                end
                result = JSON.parse(res.body)
                return result
            else
                return nil
            end
        end

        def self.check_accounts_balance
            token = get_auth_token()
            
            if token
                url = @@base_url_production + "/standard/v1/users/balance"

                uri = URI(url)

                req = Net::HTTP::Get.new(uri)

                ## Set the headers

                #set accept
                req['Accept'] = "*/*"
                #set token
                req['Authorization'] = "Bearer #{token}"
                
                #set country
                req['X-Country'] = "UG"

                #set currency
                req['X-Currency'] = "UGX"

                res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
                    http.request(req)
                end
                result = JSON.parse(res.body)
                return result
            else
                return nil
            end
        end

        def self.get_account_holder_information(phone_number)
            token = get_auth_token()
            
            if token
                phone_number = format_number(phone_number)
                url = @@base_url_production + "/standard/v1/users/#{phone_number}"

                uri = URI(url)

                req = Net::HTTP::Get.new(uri)

                ## Set the headers
                #set content-type
                req['Content-Type'] = "application/json"

                #set accept
                req['Accept'] = "*/*"
                #set token
                req['Authorization'] = "Bearer #{token}"
                
                #set country
                req['X-Country'] = "UG"

                #set currency
                req['X-Currency'] = "UGX"

                res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
                    http.request(req)
                end
                result = JSON.parse(res.body)
                return result
            else
                return nil
            end

        end

        def self.get_auth_token
            url = @@base_url_production + "/auth/oauth2/token"

            uri = URI(url)

            req = Net::HTTP::Post.new(uri)

            ## Set the headers
            #set content-type
            req['Content-Type'] = "application/json"

            #set accept
            req['Accept'] = "*/*"

            # Set request body
            request_body = {
                client_id: @@client_id,
                client_secret: @@client_secret,
                grant_type: "client_credentials"
            }

            req.body = request_body.to_json

            res = Net::HTTP.start(uri.hostname, uri.port,:use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
                http.request(req)
            end

            result = JSON.parse(res.body)

            if res.code == "200"
                return result["access_token"]
            else
                return nil
            end
        end

        def self.encrypt_pin
            public_key = OpenSSL::PKey::RSA.new(Base64.decode64(@@public_key))
            encrypted_passcode = Base64.encode64(public_key.public_encrypt(@@pin))

            return encrypted_passcode.gsub("\n", "")
        end

        def self.format_number(phone_number)
            return phone_number[3..-1]
        end
  
    end
end