require "rails_helper"

RSpec.describe Relworks, type: :model do
  # before :each do
  #   @relworks = Relworks.new
  # end
  describe "#request_payment" do
    # stub the request
    let(:response) do
      {
        "success" => true,
        "message" => "Request payment in progress.",
        "internal_reference" => "d3ae5e14f05fcc58427331d38cb11d42"
      }
    end
    let(:payment_request) do
      stub_request(
        :post,
        "https://payments.relworx.com/api/mobile-money/request-payment"
      ).to_return(status: 200, body: response.to_json, headers: {})
    end
    before { payment_request }

    let(:client) { Relworks.new }

    it "returns a status and data" do
      status, data =
        client.request_payment(
          msisdn: "+256701345672",
          amount: 500.0,
          description: "Payment for order #1234."
        )
      expect(status).to eq(200)
      expect(data).to eq(response)
      expect(data["success"]).to be true
      expect(payment_request).to have_been_requested
    end
  end

  describe "#make_payment" do
    let(:response) do
      {
        "success" => true,
        "message" => "Send payment in progress.",
        "internal_reference" => "d3ae5e14f05fcc58427331d38cb11d42"
      }
    end

    let(:payment_request) do
      stub_request(
        :post,
        "https://payments.relworx.com/api/mobile-money/send-payment"
      ).to_return(status: 200, body: response.to_json, headers: {})
    end
    # stub the request
    before { payment_request }

    let(:client) { Relworks.new }

    it "returns a status and data" do
      status, data =
        client.make_payment(
          msisdn: "+256701345672",
          amount: 500.0,
          description: "Send Payment to John Doe."
        )

      expect(status).to eq(200)
      expect(data).to eq(response)
      expect(data["success"]).to be true
      expect(payment_request).to have_been_requested
    end
  end

  describe "#check_balance" do
    let(:response) { { "success" => true, "balance" => 0.0 } }

    let(:payment_request) do
      stub_request(
        :get,
        %r{https://payments.relworx.com/api/mobile-money/check-wallet-balance*}
      ).to_return(status: 200, body: response.to_json, headers: {})
    end

    let(:client) { Relworks.new }

    # stub the request
    before { payment_request }
    it "returns a status and data" do
      status, data = client.check_balance()

      expect(status).to eq(200)
      expect(data).to eq(response)
      expect(data["success"]).to be true
      expect(payment_request).to have_been_requested
    end
  end

  describe "#transaction_status" do
    let(:internal_reference) { Faker::Alphanumeric.alphanumeric(number: 20) }
    let(:response) do
      {
        "success" => true,
        "status" => "success",
        "message" => "Request payment completed successfully.",
        "customer_reference" => "xxxxxxxxxxxxxxxxx",
        "internal_reference" => "xxxxxxxxxxxxxxxxx",
        "msisdn" => "+256701000098",
        "amount" => 500.0,
        "currency" => "UGX",
        "provider" => "AIRTEL_UGANDA",
        "charge" => 12.5,
        "request_status" => "success",
        "remote_ip" => "102.85.4.217",
        "provider_transaction_id" => "1080783XXXXX",
        "completed_at" => "2025-04-10T15:12:58.977+03:00"
      }
    end

    let(:payment_request) do
      stub_request(
        :get,
        "https://payments.relworx.com/api/mobile-money/check-transaction-status"
      ).with(
        query: {
          "account_no" => ENV["RELWORKS_ACCOUNT_NO"],
          "internal_reference" => internal_reference
        }
      ).to_return(status: 200, body: response.to_json, headers: {})
    end

    # stub the request
    before { payment_request }

    let(:client) { Relworks.new }
    it "returns a status and data" do
      status, data =
        client.check_transaction_status(internal_reference: internal_reference)

      expect(status).to eq(200)
      expect(data).to eq(response)
      expect(data["success"]).to be true
      expect(payment_request).to have_been_requested
    end
  end
end
