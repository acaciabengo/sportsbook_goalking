require 'rails_helper'
require 'swagger_helper'

RSpec.describe "Api::V1::Transactions", type: :request do
  let(:user) { Fabricate(:user, balance: 50000.0) }
  let(:auth_headers) do
    token = JWT.encode(
      { sub: user.id, exp: 24.hours.from_now.to_i, iat: Time.now.to_i },
      ENV['DEVISE_JWT_SECRET_KEY'],
      'HS256'
    )
    { 'Authorization' => "Bearer #{token}" }
  end

  path '/api/v1/transactions' do
    get 'Lists all transactions for the current user' do
      tags 'Transactions'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'

      let(:Authorization) { auth_headers['Authorization'] }

      response '200', 'successful' do
        before do
          Fabricate.times(2, :transaction, user: user)
        end
        schema type: :object,
          properties: {
            current_page: { type: :integer },
            total_pages: { type: :integer },
            total_count: { type: :integer },
            transactions: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  amount: { type: :float },
                  balance_before: { type: :string },
                  balance_after: { type: :string },
                  category: { type: :string },
                  created_at: { type: :string, format: 'date-time' }
                }
              }
            }
          }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end

  path '/api/v1/transactions/deposit' do
    post 'Creates a deposit transaction' do
      tags 'Transactions'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'
      
      let(:Authorization) { auth_headers['Authorization'] }
      let(:deposit_params) do
        {
          amount: 10000,
          phone_number: user.phone_number
        }
      end
      
      parameter name: :deposit_params, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :number, example: 10000 },
          phone_number: { type: :string, example: '256700000000' }
        },
        required: ['amount']
      }

      response '200', 'deposit initiated' do
        before do
          allow(DepositsJob).to receive(:perform_async)
        end
        run_test!
      end

      response '400', 'bad request' do
        let(:deposit_params) { { amount: -1000 } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end

  path '/api/v1/transactions/withdraw' do
    post 'Creates a withdrawal transaction' do
      tags 'Transactions'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'
      
      let(:Authorization) { auth_headers['Authorization'] }
      let!(:user_deposit) { Fabricate(:deposit, user: user) }
      let(:withdraw_params) do
        {
          amount: 5000,
          phone_number: user.phone_number
        }
      end
      
      parameter name: :withdraw_params, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :number, example: 5000 },
          phone_number: { type: :string, example: '256700000000' }
        },
        required: ['amount']
      }

      response '200', 'withdrawal initiated' do
        before do
          allow(WithdrawsJob).to receive(:perform_async)
        end
        run_test!
      end

      response '400', 'bad request (e.g. insufficient balance)' do
        let(:withdraw_params) { { amount: 999999999 } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end

  # ===========================================================================
  # GET /api/v1/transactions - List User Transactions
  # ===========================================================================
  describe "GET /api/v1/transactions" do
    context "when user is authenticated" do
      context "with transactions" do
        let!(:deposit) do
          Fabricate(:transaction,
            user: user,
            amount: 10000.0,
            balance_before: 0.0,
            balance_after: 10000.0,
            category: 'Deposit',
            created_at: 2.days.ago
          )
        end

        let!(:withdrawal) do
          Fabricate(:transaction,
            user: user,
            amount: 5000.0,
            balance_before: 10000.0,
            balance_after: 5000.0,
            category: 'Withdraw',
            created_at: 1.day.ago
          )
        end

        let!(:bet_placement) do
          Fabricate(:transaction,
            user: user,
            amount: 1000.0,
            balance_before: 5000.0,
            balance_after: 4000.0,
            category: 'Bet',
            created_at: 1.hour.ago
          )
        end

        before do
          get "/api/v1/transactions", headers: auth_headers
        end

        it "returns http success" do
          expect(response).to have_http_status(:success)
        end

        it "returns paginated response structure" do
          json = JSON.parse(response.body)
          
          expect(json).to have_key('current_page')
          expect(json).to have_key('total_pages')
          expect(json).to have_key('total_count')
          expect(json).to have_key('transactions')
        end

        it "returns transactions array" do
          json = JSON.parse(response.body)
          
          expect(json['transactions']).to be_an(Array)
          expect(json['transactions'].length).to eq(3)
        end

        it "returns transactions in descending order by created_at" do
          json = JSON.parse(response.body)
          transactions = json['transactions']
          
          expect(transactions.first['id']).to eq(bet_placement.id)
          expect(transactions.second['id']).to eq(withdrawal.id)
          expect(transactions.third['id']).to eq(deposit.id)
        end

        it "includes transaction details" do
          json = JSON.parse(response.body)
          transaction = json['transactions'].first
          
          expect(transaction).to have_key('id')
          expect(transaction).to have_key('amount')
          expect(transaction).to have_key('balance_before')
          expect(transaction).to have_key('balance_after')
          expect(transaction).to have_key('created_at')
          expect(transaction).to have_key('category')
        end

        it "only includes specified fields" do
          json = JSON.parse(response.body)
          transaction = json['transactions'].first
          
          expect(transaction.keys.sort).to eq(
            ['id', 'amount', 'balance_before', 
             'balance_after', 'created_at', 'category'].sort
          )
        end

        it "does not expose sensitive fields" do
          json = JSON.parse(response.body)
          transaction = json['transactions'].first
          
          expect(transaction).not_to have_key('user_id')
          expect(transaction).not_to have_key('reference')
          expect(transaction).not_to have_key('phone_number')
        end

        it "returns correct pagination info" do
          json = JSON.parse(response.body)
          
          expect(json['current_page']).to eq(1)
          expect(json['total_count']).to eq(3)
          expect(json['total_pages']).to eq(1)
        end
      end

      context "with no transactions" do
        before do
          get "/api/v1/transactions", headers: auth_headers
        end

        it "returns empty transactions array" do
          json = JSON.parse(response.body)
          
          expect(json['transactions']).to eq([])
        end

        it "returns zero total_count" do
          json = JSON.parse(response.body)
          
          expect(json['total_count']).to eq(0)
        end
      end

      context "with pagination" do

        before do
          25.times do |i|
            Fabricate(:transaction,
              user: user,
              amount: 1000.0 + i,
              created_at: (25 - i).hours.ago
            )
          end
        end

        it "paginates results with default page size of 20" do
          get "/api/v1/transactions", headers: auth_headers
          json = JSON.parse(response.body)
          
          expect(json['transactions'].length).to eq(20)
        end

        it "returns correct page information" do
          get "/api/v1/transactions", headers: auth_headers
          json = JSON.parse(response.body)

          # puts "total transactions: #{Transaction.count}"
          # puts "response body: \n #{response.body}"
          # puts "total user transactions: #{user.transactions.count}"
          
          expect(json['current_page']).to eq(1)
          expect(json['total_pages']).to eq(2)
          expect(json['total_count']).to eq(25)
        end

        it "supports page parameter" do
          get "/api/v1/transactions", params: { page: 2 }, headers: auth_headers
          json = JSON.parse(response.body)
          
          expect(json['current_page']).to eq(2)
          expect(json['transactions'].length).to eq(5)
        end
      end

      context "only shows current user's transactions" do
        let(:other_user) { Fabricate(:user) }
        
        let!(:user_transaction) do
          Fabricate(:transaction, user: user, amount: 1000.0)
        end
        
        let!(:other_user_transaction) do
          Fabricate(:transaction, user: other_user, amount: 2000.0)
        end

        before do
          get "/api/v1/transactions", headers: auth_headers
        end

        it "only returns authenticated user's transactions" do
          json = JSON.parse(response.body)
          transaction_ids = json['transactions'].map { |t| t['id'] }
          
          expect(transaction_ids).to include(user_transaction.id)
          expect(transaction_ids).not_to include(other_user_transaction.id)
        end
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized" do
        get "/api/v1/transactions"
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================================================
  # POST /api/v1/transactions/deposit - Deposit Funds
  # ===========================================================================
  describe "POST /api/v1/transactions/deposit" do
    context "when user is authenticated" do
      context "with valid parameters" do
        let(:deposit_params) do
          {
            amount: 10000.0,
            phone_number: user.phone_number
          }
        end

        before do
          allow(DepositsJob).to receive(:perform_async)
        end

        it "returns http success" do
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
          
          expect(response).to have_http_status(:success)
        end

        it "creates a pending transaction" do
          expect {
            post "/api/v1/transactions/deposit", 
                 params: deposit_params, 
                 headers: auth_headers
          }.to change(Transaction, :count).by(1)
        end

        it "creates transaction with correct attributes" do
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
          
          transaction = Transaction.last
          
          expect(transaction.user_id).to eq(user.id)
          expect(transaction.amount).to eq(10000.0)
          expect(transaction.phone_number).to eq(user.phone_number)
          expect(transaction.category).to eq('Deposit')
          expect(transaction.status).to eq('PENDING')
          expect(transaction.currency).to eq('UGX')
          expect(transaction.reference).to be_present
        end

        it "generates a unique reference" do
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
          
          transaction = Transaction.last
          
          expect(transaction.reference).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
        end

        it "enqueues DepositsJob" do
          expect(DepositsJob).to receive(:perform_async).with(kind_of(Integer))
          
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
        end

        it "returns success message" do
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
          
          json = JSON.parse(response.body)
          
          expect(json['message']).to eq('Please wait while we process your transaction...')
        end
      end

      context "with custom phone number" do
        let(:deposit_params) do
          {
            amount: 5000.0,
            phone_number: '256711111111'
          }
        end

        before do
          allow(DepositsJob).to receive(:perform_async)
        end

        it "uses provided phone number" do
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers

          transaction = Transaction.last.reload
          
          expect(transaction.phone_number).to eq('256711111111')
        end
      end

      context "without phone number parameter" do
        let(:deposit_params) do
          { amount: 5000.0 }
        end

        before do
          allow(DepositsJob).to receive(:perform_async)
        end

        it "uses user's phone number by default" do
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
          
          transaction = Transaction.last
          
          expect(transaction.phone_number).to eq(user.phone_number)
        end
      end

      context "with invalid parameters" do
        let(:deposit_params) do
          { amount: -1000.0 }
        end

        it "returns bad request" do
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
          
          expect(response).to have_http_status(:bad_request)
        end

        it "does not create a transaction" do
          expect {
            post "/api/v1/transactions/deposit", 
                 params: deposit_params, 
                 headers: auth_headers
          }.not_to change(Transaction, :count)

          # print the response body for debugging
          puts "Response body: #{response.body}"
        end

        it "returns error message" do
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
          
          json = JSON.parse(response.body)
          
          expect(json['message']).to eq('Deposit amount must be greater than zero.')
        end

        it "does not enqueue worker" do
          expect(DepositsJob).not_to receive(:perform_async)
          
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
        end
      end

      context "with missing amount parameter" do
        let(:deposit_params) { {} }

        it "returns bad request" do
          post "/api/v1/transactions/deposit", 
               params: deposit_params, 
               headers: auth_headers
          
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized" do
        post "/api/v1/transactions/deposit", params: { amount: 10000.0 }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================================================
  # POST /api/v1/transactions/withdraw - Withdraw Funds
  # ===========================================================================
  describe "POST /api/v1/transactions/withdraw" do
    context "when user is authenticated" do
      context "with valid parameters and sufficient balance" do
        let!(:previous_deposit) do
          Fabricate(:transaction,
            user: user,
            amount: 10000.0,
            category: 'Deposit',
            status: 'COMPLETED'
          )
        end

        let!(:deposit) do
          Fabricate(:deposit, user: user)
        end

        let(:withdraw_params) do
          {
            amount: 5000.0,
            phone_number: user.phone_number
          }
        end

        before do
          allow(WithdrawsJob).to receive(:perform_async)
        end

        it "returns http success" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          expect(response).to have_http_status(:success)
        end

        it "creates a pending withdrawal transaction" do
          expect {
            post "/api/v1/transactions/withdraw", 
                 params: withdraw_params, 
                 headers: auth_headers
          }.to change(Transaction, :count).by(1)
        end

        it "creates transaction with correct attributes" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          transaction = Transaction.last
          
          expect(transaction.user_id).to eq(user.id)
          expect(transaction.amount).to eq(5000.0)
          expect(transaction.phone_number).to eq(user.phone_number)
          expect(transaction.category).to eq('Withdraw')
          expect(transaction.status).to eq('PENDING')
          expect(transaction.currency).to eq('UGX')
        end

        it "enqueues WithdrawsJob" do
          expect(WithdrawsJob).to receive(:perform_async).with(kind_of(Integer))
          
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
        end

        it "returns success message" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          json = JSON.parse(response.body)
          
          expect(json['message']).to eq('Please wait while we process your withdrawal...')
        end
      end

      context "with custom phone number" do
        let!(:previous_transaction) do
          Fabricate(:transaction,
            user: user,
            amount: 10000.0,
            category: 'Deposit',
            status: 'COMPLETED'
          )
        end

        let!(:previous_deposit) do 
          Fabricate(:transaction,
            user: user,
            amount: 10000.0,
            category: 'Deposit',
            status: 'COMPLETED'
          )
        end

        let!(:deposit) do
          Fabricate(:deposit, user: user)
        end

        let(:withdraw_params) do
          {
            amount: 5000.0,
            phone_number: '256722222222'
          }
        end

        before do
          allow(WithdrawsJob).to receive(:perform_async)
        end

        it "uses provided phone number" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers

          puts "Response body for phone number: #{response.body}"
          
          transaction = Transaction.last
          
          expect(transaction.phone_number).to eq('256722222222')
        end
      end

      context "without prior deposits" do
        let(:withdraw_params) do
          { amount: 5000.0 }
        end

        it "returns bad request" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          expect(response).to have_http_status(:bad_request)
        end

        it "does not create a transaction" do
          expect {
            post "/api/v1/transactions/withdraw", 
                 params: withdraw_params, 
                 headers: auth_headers
          }.not_to change(Transaction, :count)
        end

        it "returns error message about deposits" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          json = JSON.parse(response.body)
          
          expect(json['message']).to eq('You must have made at least one deposit before making a withdrawal.')
        end

        it "does not enqueue worker" do
          expect(WithdrawsJob).not_to receive(:perform_async)
          
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
        end
      end

      context "with insufficient balance" do
        let!(:previous_deposit) do
          Fabricate(:transaction,
            user: user,
            amount: 1000.0,
            category: 'Deposit',
            status: 'COMPLETED'
          )
        end

        let!(:deposit) do
          Fabricate(:deposit, user: user)
        end

        let(:withdraw_params) do
          { amount: 60000.0 }  # More than user's balance of 50000
        end

        it "returns bad request" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          expect(response).to have_http_status(:bad_request)
        end

        it "does not create a transaction" do
          expect {
            post "/api/v1/transactions/withdraw", 
                 params: withdraw_params, 
                 headers: auth_headers
          }.not_to change(Transaction, :count)
        end

        it "returns insufficient balance error" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          json = JSON.parse(response.body)
          
          expect(json['message']).to eq('Insufficient balance for this withdrawal.')
        end

        it "does not enqueue worker" do
          expect(WithdrawsJob).not_to receive(:perform_async)
          
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
        end
      end

      context "with invalid amount" do
        let!(:previous_deposit) do
          Fabricate(:transaction,
            user: user,
            amount: 10000.0,
            category: 'Deposit',
            status: 'COMPLETED'
          )
        end

        let(:withdraw_params) do
          { amount: -5000.0 }
        end

        it "returns bad request" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          expect(response).to have_http_status(:bad_request)
        end

        it "does not create a transaction" do
          expect {
            post "/api/v1/transactions/withdraw", 
                 params: withdraw_params, 
                 headers: auth_headers
          }.not_to change(Transaction, :count)
        end
      end

      context "with zero amount" do
        let!(:previous_deposit) do
          Fabricate(:transaction,
            user: user,
            amount: 10000.0,
            category: 'Deposit',
            status: 'COMPLETED'
          )
        end

        let(:withdraw_params) do
          { amount: 0 }
        end

        it "returns bad request" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          expect(response).to have_http_status(:bad_request)
        end
      end

      context "with missing amount parameter" do
        let!(:previous_deposit) do
          Fabricate(:transaction,
            user: user,
            amount: 10000.0,
            category: 'Deposit',
            status: 'COMPLETED'
          )
        end

        let(:withdraw_params) { {} }

        it "returns bad request" do
          post "/api/v1/transactions/withdraw", 
               params: withdraw_params, 
               headers: auth_headers
          
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized" do
        post "/api/v1/transactions/withdraw", params: { amount: 5000.0 }
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===========================================================================
  # Edge Cases and Security Tests
  # ===========================================================================
  describe "Security and Edge Cases" do
    context "reference generation" do
      it "generates unique references for multiple transactions" do
        allow(DepositsJob).to receive(:perform_async)
        
        references = []
        3.times do
          post "/api/v1/transactions/deposit", 
               params: { amount: 1000.0 }, 
               headers: auth_headers
          references << Transaction.last.reference
        end
        
        expect(references.uniq.length).to eq(3)
      end

      it "generates valid UUID format" do
        allow(DepositsJob).to receive(:perform_async)
        
        post "/api/v1/transactions/deposit", 
             params: { amount: 1000.0 }, 
             headers: auth_headers
        
        reference = Transaction.last.reference
        uuid_pattern = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
        
        expect(reference).to match(uuid_pattern)
      end
    end

    context "concurrent transactions" do
      it "handles multiple deposit requests" do
        allow(DepositsJob).to receive(:perform_async)
        
        expect {
          3.times do
            post "/api/v1/transactions/deposit", 
                 params: { amount: 1000.0 }, 
                 headers: auth_headers
          end
        }.to change(Transaction, :count).by(3)
      end
    end

    context "parameter sanitization" do
      it "permits only allowed parameters" do
        allow(DepositsJob).to receive(:perform_async)
        
        post "/api/v1/transactions/deposit", 
             params: { 
               amount: 1000.0, 
               user_id: 999,  # Should be ignored
               status: 'COMPLETED'  # Should be ignored
             }, 
             headers: auth_headers
        
        transaction = Transaction.last
        
        expect(transaction.user_id).to eq(user.id)  # Not 999
        expect(transaction.status).to eq('PENDING')  # Not COMPLETED
      end
    end
  end
end