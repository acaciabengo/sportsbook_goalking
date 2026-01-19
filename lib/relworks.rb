class Relworks
  def initialize()
    @default_headers = {
      "Authorization" => "Bearer #{ENV["RELWORKS_BEARER_TOKEN"]}",
      "Accept" => "application/vnd.relworx.v2",
      "Content-Type" => "application/json"
    }
    @base_url = "https://payments.relworx.com/api"
    @client = client()
  end

  def client()
    conn =
      Faraday.new(url: @base_url, headers: @default_headers) do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
      end
    conn
  end

  def format_msisdn(msisdn)
    return nil if msisdn.blank?
    phone = msisdn.to_s.gsub(/\s+/, '')
    phone.start_with?('+') ? phone : "+#{phone}"
  end

  def request_payment(
    msisdn: nil,
    amount: nil,
    currency: "UGX",
    description: nil
  )
    body = {
      account_no: ENV["RELWORKS_ACCOUNT_NO"],
      reference: Time.now.to_i.to_s + "#{SecureRandom.hex(10)}",
      msisdn: format_msisdn(msisdn),
      currency: currency,
      amount: amount.to_f
    }

    body[:description] = description if description

    response =
      @client.post do |req|
        req.url "/mobile-money/request-payment"
        req.body = body.to_json
      end
    status = response.status
    data = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      { "success" => false, "message" => response.body.to_s.truncate(200) }
    end
    return status, data
  end

  def make_payment(msisdn: nil, amount: nil, currency: "UGX", description: nil)
    body = {
      account_no: ENV["RELWORKS_ACCOUNT_NO"],
      reference: Time.now.to_i.to_s + "#{SecureRandom.hex(10)}",
      msisdn: format_msisdn(msisdn),
      currency: currency,
      amount: amount.to_f
    }

    body[:description] = description if description

    response =
      @client.post do |req|
        req.url "/mobile-money/send-payment"
        req.body = body.to_json
      end
    status = response.status
    data = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      { "success" => false, "message" => response.body.to_s.truncate(200) }
    end
    return status, data
  end

  def check_balance()
    response =
      @client.get do |req|
        req.url "/mobile-money/check-wallet-balance"
        req.params = { account_no: ENV["RELWORKS_ACCOUNT_NO"], currency: "UGX" }
      end
    status = response.status
    data = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      { "success" => false, "message" => response.body.to_s.truncate(200) }
    end
    return status, data
  end

  def check_transaction_status(internal_reference: nil)
    response =
      @client.get do |req|
        req.url "/mobile-money/check-transaction-status"
        req.params = {
          account_no: ENV["RELWORKS_ACCOUNT_NO"],
          internal_reference: internal_reference
        }
      end
    status = response.status
    data = begin
      JSON.parse(response.body)
    rescue JSON::ParserError
      { "success" => false, "message" => response.body.to_s.truncate(200) }
    end
    return status, data
  end
end
