module MobileMoney
  class MtnOpenApi
    require 'openssl'
    require 'json'
    require 'uri'
    require 'net/http'
    require 'logger'

    @@collection_sub_key  = ENV['MTN_COLLECTION_SUB_KEY']
    @@transfer_sub_key    = ENV['MTN_TRANSFER_SUB_KEY']
    @@collection_api_id   = ENV['MTN_COLLECTION_API_ID']
    @@collection_api_key  = ENV['MTN_COLLECTION_API_KEY']
    @@transfer_api_id     = ENV['MTN_TRANSFER_API_ID']
    @@transfer_api_key    = ENV['MTN_TRANSFER_API_KEY']

    # @@base_url = "https://sandbox.momodeveloper.mtn.com/"
    @@base_url = ENV['MTN_BASE_URL']

    def self.request_payments(amount, ext_reference, phone_number)
      token = get_collections_auth_token()
      if token
        url = @@base_url + "collection/v1_0/requesttopay"
        callback_url = "https://betsports.ug/confirmation/mtn/payment"

        uri = URI(url)

        req = Net::HTTP::Post.new(uri)

        ## Set the headers
        #set token
        req['Authorization'] = "Bearer #{token}"

        #set transactions callback url
        req['X-Callback-Url'] = callback_url

        #set the transaction reference
        req['X-Reference-Id'] = ext_reference

        #set Enviroment
        req['X-Target-Environment'] = "mtnuganda"

        #set content type
        req['Content-Type'] = "application/json"

        #set the subscription keys
        req['Ocp-Apim-Subscription-Key'] = @@collection_sub_key

        request_body = {
          amount: amount,
          currency: "UGX",
          externalId: ext_reference,
          payer: {
            partyIdType: "MSISDN",
            partyId: phone_number
          },
          payerMessage: "BetSports",
          payeeNote: "BetSports"
        }

        req.body = request_body.to_json

        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          http.request(req)
        end
        @@logger.error(res.body)

        return res.code #Expecting code to be 202 on successfull transaction
      else
        return nil
      end
    end

    def self.check_collection_status(ext_reference)
      token = get_collections_auth_token()
      if token
        url = @@base_url + "collection/v1_0/requesttopay/#{ext_reference}"

        uri = URI(url)

        req = Net::HTTP::Get.new(uri)

        ## Set the headers
        #set token
        req['Authorization'] = "Bearer #{token}"

        #set Enviroment
        req['X-Target-Environment'] = "mtnuganda"

        #set the subscription keys
        req['Ocp-Apim-Subscription-Key'] = @@collection_sub_key

        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          http.request(req)
        end
        result = JSON.parse(res.body)
        return result
      else
        return nil
      end
    end

    def self.check_collections_balance
      token = get_collections_auth_token()
      if token
        url = @@base_url + "collection/v1_0/account/balance"

        uri = URI(url)

        req = Net::HTTP::Get.new(uri)

        ## Set the headers
        #set token
        req['Authorization'] = "Bearer #{token}"

        #set Enviroment
        req['X-Target-Environment'] = "mtnuganda"

        #set the subscription keys
        req['Ocp-Apim-Subscription-Key'] = @@collection_sub_key

        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          http.request(req)
        end
        result = JSON.parse(res.body)
        return result
      else
        return nil
      end
    end

    def self.make_transfer(amount, ext_reference, phone_number)
      token = get_payouts_auth_token()
      if token
        url = @@base_url + "disbursement/v1_0/transfer"
        callback_url = "https://betsports.ug/confirmation/mtn/payment"
        uri = URI(url)

        req = Net::HTTP::Post.new(uri)

        ## Set the headers
        #set token
        req['Authorization'] = "Bearer #{token}"

        #set transactions callback url
        req['X-Callback-Url'] = callback_url

        #set the transaction reference
        req['X-Reference-Id'] = ext_reference

        #set Enviroment
        req['X-Target-Environment'] = "mtnuganda"

        #set content type
        req['Content-Type'] = "application/json"

        #set the subscription keys
        req['Ocp-Apim-Subscription-Key'] = @@transfer_sub_key

        request_body = {
          amount: amount,
          currency: "UGX",
          externalId: ext_reference,
          payee: {
            partyIdType: "MSISDN",
            partyId: phone_number
          },
          payerMessage: "BetSports",
          payeeNote: "BetSports"
        }

        req.body = request_body.to_json

        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          http.request(req)
        end

        return res.code
      else
        return nil
      end
    end

    def self.check_transfer_status(ext_reference)
      token = get_payouts_auth_token()
      if token
        url = @@base_url + "disbursement/v1_0/transfer/#{ext_reference}"

        uri = URI(url)

        req = Net::HTTP::Get.new(uri)

        ## Set the headers
        #set token
        req['Authorization'] = "Bearer #{token}"

        #set Enviroment
        req['X-Target-Environment'] = "mtnuganda"

        #set the subscription keys
        req['Ocp-Apim-Subscription-Key'] = @@transfer_sub_key

        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          http.request(req)
        end
        result = JSON.parse(res.body)
        return result
      else
        return nil
      end
    end

    def self.check_disbursement_balance
      token = get_payouts_auth_token()
      if token
        url = @@base_url + "disbursement/v1_0/account/balance"

        uri = URI(url)

        req = Net::HTTP::Get.new(uri)

        ## Set the headers
        #set token
        req['Authorization'] = "Bearer #{token}"

        #set Enviroment
        req['X-Target-Environment'] = "mtnuganda"

        #set the subscription keys
        req['Ocp-Apim-Subscription-Key'] = @@transfer_sub_key

        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          http.request(req)
        end
        result = JSON.parse(res.body)
        return result
      else
        return nil
      end
    end

    def self.get_collections_auth_token
      #api_user = ApiUser.find_by(api_id: user_id)
      if true
        #process the token and return the token
        api_id = @@collection_api_id
        api_key = @@collection_api_key

        url = @@base_url + "collection/token/"

        uri = URI(url)

        req = Net::HTTP::Post.new(uri)

        ## Set the headers

        #set Authourization
        req['Authourization'] = req.basic_auth(api_id, api_key)

        #set the subscription keys
        req['Ocp-Apim-Subscription-Key'] = @@collection_sub_key

        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          http.request(req)
        end
        result = JSON.parse(res.body)
        p result
        case res.code
        when '200'
          return result['access_token']
        else
          return nil
        end
      else
        return nil
      end
    end

    def self.get_payouts_auth_token
      if true
        #process the token and return the token
        api_id = @@transfer_api_id
        api_key = @@transfer_api_key

        url = @@base_url + "disbursement/token/"

        uri = URI(url)

        req = Net::HTTP::Post.new(uri)

        ## Set the headers

        #set Authourization
        req['Authourization'] = req.basic_auth(api_id, api_key)

        #set the subscription keys
        req['Ocp-Apim-Subscription-Key'] = @@transfer_sub_key

        res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          http.request(req)
        end
        result = JSON.parse(res.body)
        p result
        case res.code
        when '200'
          return result['access_token']
        else
          return nil
        end
      else
        return nil
      end
    end

    def self.register_api_user(user_id)
      api_user = ApiUser.find_by(api_id: user_id)
      if api_user.user_type == 'collections'
        sub_key = @@collection_sub_key
      end
      if api_user.user_type == 'transfer'
        sub_key = @@transfer_sub_key
      end

      url = "https://sandbox.momodeveloper.mtn.com/v1_0/apiuser"

      uri = URI(url)

      req = Net::HTTP::Post.new(uri)

      #set the transaction reference
      req['X-Reference-Id'] = user_id

      #set content type
      req['Content-Type'] = "application/json"

      #set the subscription keys
      req['Ocp-Apim-Subscription-Key'] = sub_key

      request_body = {
        providerCallbackHost: "betcity.co.ug"
      }

      req.body = request_body.to_json

      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(req)
      end

      case res.code
      when '201'
        api_user.update(registered: true)
        return true
      else
        return res
      end
    end

    def self.receive_api_key(user_id)
      api_user = ApiUser.find_by(api_id: user_id)
      if api_user.user_type == 'collections'
        sub_key = @@collection_sub_key
      end
      if api_user.user_type == 'transfer'
        sub_key = @@transfer_sub_key
      end
      api_user = ApiUser.find_by(api_id: user_id)
      url = "https://sandbox.momodeveloper.mtn.com/v1_0/apiuser/#{user_id}/apikey"
      uri = URI(url)

      req = Net::HTTP::Post.new(uri)

      #set the subscription keys
      req['Ocp-Apim-Subscription-Key'] = sub_key

      res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(req)
      end

      result = JSON.parse(res.body)

      case res.code
      when '201'
        api_key = result['apiKey']
        return api_key
      else
        return nil
      end
    end
  end
end