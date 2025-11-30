require 'rails_helper'

RSpec.describe "Api::V1::Transactions", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/api/v1/transactions/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /deposit" do
    it "returns http success" do
      get "/api/v1/transactions/deposit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /withdraw" do
    it "returns http success" do
      get "/api/v1/transactions/withdraw"
      expect(response).to have_http_status(:success)
    end
  end

end
