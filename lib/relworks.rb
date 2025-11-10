class Relworks
  @base_url = " https://payments.relworx.com/api"

  def initialize()
    @client = client()
    @default_headers = {
      "Authorization" => "Bearer #{ENV["RELWORKS_BEARER_TOKEN"]}",
      "Accept" => "application/vnd.relworx.v2",
      "Content-Type" => "application/json"
    }
  end

  def client()
    conn =
      Faraday.new(url: @base_url) do |faraday|
        faraday.request :url_encoded
        faraday.adapter Faraday.default_adapter
        faraday.headers = @default_headers
      end
    conn
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
      msisdn: msisdn,
      currency: currency,
      amount: amount
    }

    body[:description] = description if description

    response =
      @client.post do |req|
        req.url "/mobile-money/request-payment"
        req.body = body.to_json
      end
    status = response.status
    data = JSON.parse(response.body)
    return status, data
  end

  def make_payment(msisdn: nil, amount: nil, currency: "UGX", description: nil)
    body = {
      account_no: ENV["RELWORKS_ACCOUNT_NO"],
      reference: Time.now.to_i.to_s + "#{SecureRandom.hex(10)}",
      msisdn: msisdn,
      currency: currency,
      amount: amount
    }

    body[:description] = description if description

    response =
      @client.post do |req|
        req.url "/mobile-money/send-payment"
        req.body = body.to_json
      end
    status = response.status
    data = JSON.parse(response.body)
    return status, data
  end

  def check_balance()
    response =
      @client.get do |req|
        req.url "/mobile-money/check-wallet-balance"
        req.params = { account_no: ENV["RELWORKS_ACCOUNT_NO"], currency: "UGX" }
      end
    status = response.status
    data = JSON.parse(response.body)
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
    data = JSON.parse(response.body)
    return status, data
  end
end
