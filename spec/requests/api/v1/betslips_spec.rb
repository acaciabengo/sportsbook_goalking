require 'rails_helper'
require 'swagger_helper'

RSpec.describe "Api::V1::Betslips", type: :request do
  let(:user) { Fabricate(:user, balance: 10000.0) }
  let(:jwt_token) { JWT.encode({ sub: user.id, exp: 24.hours.from_now.to_i }, ENV['DEVISE_JWT_SECRET_KEY'], 'HS256') }
  let(:auth_headers) { { 'Authorization' => "Bearer #{jwt_token}" } }

  path '/api/v1/betslips' do
    get 'Lists all betslips for the current user' do
      tags 'Betslips'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'

      let(:Authorization) { auth_headers['Authorization'] }

      response '200', 'successful' do
        before do
          Fabricate.times(2, :bet_slip, user: user)
        end
        schema type: :object,
          properties: {
            current_page: { type: :integer, example: 1 },
            total_pages: { type: :integer, example: 1 },
            total_count: { type: :integer, example: 5 },
            betslips: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  stake: { type: :string },
                  win_amount: { type: :string },
                  payout: { type: :string },
                  status: { type: :string },
                  result: { type: :string, nullable: true },
                  created_at: { type: :string, format: 'date-time' },
                  bets: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        id: { type: :integer },
                        fixture_id: { type: :integer },
                        market_identifier: { type: :string },
                        odds: { type: :string },
                        outcome: { type: :string },
                        specifier: { type: :string, nullable: true },
                        outcome_desc: { type: :string },
                        bet_type: { type: :string },
                        created_at: { type: :string, format: 'date-time' }
                      }
                    }
                  }
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

    post 'Creates a betslip' do
      tags 'Betslips'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'

      let(:Authorization) { auth_headers['Authorization'] }
      let(:fixture) { Fabricate(:fixture) }
      let(:betslip_params) do
        {
          stake: 1000,
          bets: [
            {
              fixture_id: fixture.id,
              market_identifier: '1',
              outcome: 'Home Win',
              outcome_id: '1',
              odd: 2.5,
              specifier: nil,
              bet_type: 'PreMatch'
            }
          ]
        }
      end
      
      parameter name: :betslip_params, in: :body, schema: {
        type: :object,
        properties: {
          stake: { type: :number, example: 1000 },
          bets: {
            type: :array,
            items: {
              type: :object, 
              properties: {
                fixture_id: { type: :integer },
                market_identifier: { type: :string },
                outcome: { type: :string, description: 'Outcome description' },
                outcome_id: { type: :string, description: 'Outcome ID' },
                odd: { type: :number },
                specifier: { type: :string, nullable: true },
                bet_type: { type: :string, enum: ['PreMatch', 'Live'] }
              },
              required: ['fixture_id', 'market_identifier', 'outcome', 'outcome_id', 'odd', 'bet_type']
            }
          }
        },
        required: ['stake', 'bets']
      }

      response '201', 'bet slip created' do
        schema type: :object,
          properties: {
            message: { type: :string, example: 'Bet Slip created successfully' },
            bet_slip_id: { type: :integer }
          }
        run_test!
      end

      response '400', 'bad request' do
        let(:betslip_params) { { stake: -100 } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end

  path '/api/v1/betslips/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Betslip ID'

    get 'Shows a specific betslip' do
      tags 'Betslips'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'

      let(:Authorization) { auth_headers['Authorization'] }
      let(:betslip) { Fabricate(:bet_slip, user: user) }
      let(:id) { betslip.id }

      response '200', 'successful' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            stake: { type: :string },
            odds: { type: :string },
            win_amount: { type: :string },
            payout: { type: :string },
            status: { type: :string },
            result: { type: :string, nullable: true },
            created_at: { type: :string, format: 'date-time' },
            bets: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  fixture_id: { type: :integer },
                  market_identifier: { type: :string },
                  odds: { type: :string },
                  outcome: { type: :string },
                  specifier: { type: :string, nullable: true },
                  outcome_desc: { type: :string },
                  bet_type: { type: :string },
                  created_at: { type: :string, format: 'date-time' }
                }
              }
            }
          }
        run_test!
      end

      response '404', 'bet slip not found' do
        let(:id) { 999999 }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:id) { betslip.id }
        run_test!
      end
    end
  end

  describe "GET /" do
    context "when user is authenticated" do
      before do
        Fabricate.times(5, :bet_slip, user: user)
      end

      it "returns http success" do
        get "/api/v1/betslips", headers: auth_headers
        expect(response).to have_http_status(:success)
      end

      it "returns paginated betslips" do
        get "/api/v1/betslips", headers: auth_headers
        json = JSON.parse(response.body)

        expect(json).to have_key('betslips')
        expect(json).to have_key('current_page')
        expect(json).to have_key('total_pages')
        expect(json).to have_key('total_count')
        expect(json['total_count']).to eq(5)
      end

      it "includes bet details in betslips" do
        bet_slip = Fabricate(:bet_slip, user: user)
        Fabricate(:bet, bet_slip: bet_slip, user: user)
        
        get "/api/v1/betslips", headers: auth_headers
        json = JSON.parse(response.body)
        
        betslip = json['betslips'].first
        expect(betslip).to have_key('bets')
      end

      it "orders betslips by created_at desc" do
        user.bet_slips.destroy_all
        old_slip = Fabricate(:bet_slip, user: user, created_at: 2.days.ago)
        new_slip = Fabricate(:bet_slip, user: user, created_at: 1.day.ago)
        puts "Old Slip ID: #{old_slip.id}, Created At: #{old_slip.created_at}"
        puts "New Slip ID: #{new_slip.id}, Created At: #{new_slip.created_at}"
        
        get "/api/v1/betslips", headers: auth_headers
        json = JSON.parse(response.body)
        
        betslip_ids = json['betslips'].map { |b| b['id'] }
        expect(betslip_ids.first).to eq(new_slip.id)
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/betslips"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /create" do
    let(:fixture) { Fabricate(:fixture) }
    let(:valid_params) do
      {
        stake: 1000,
        bets: [
          {
            fixture_id: fixture.id,
            market_identifier: '1',
            outcome: 'Home Win',
            outcome_id: '1',
            odd: 2.5,
            specifier: nil,
            bet_type: 'PreMatch'
          }
        ]
      }
    end

    context "when user is authenticated" do
      context "with valid parameters" do
        it "creates a new bet slip" do
          expect {
            post "/api/v1/betslips", params: valid_params, headers: auth_headers
          }.to change(BetSlip, :count).by(1)
        end

        it "creates associated bets" do
          expect {
            post "/api/v1/betslips", params: valid_params, headers: auth_headers
          }.to change(Bet, :count).by(1)
        end

        it "creates a transaction record" do
          expect {
            post "/api/v1/betslips", params: valid_params, headers: auth_headers
          }.to change(Transaction, :count).by(1)
        end

        it "deducts stake from user balance" do
          expect {
            post "/api/v1/betslips", params: valid_params, headers: auth_headers
            user.reload
          }.to change { user.balance }.by(-1000.0)
        end

        it "returns success message with bet_slip_id" do
          post "/api/v1/betslips", params: valid_params, headers: auth_headers
          json = JSON.parse(response.body)

          expect(response).to have_http_status(:created)
          expect(json['message']).to eq('Bet Slip created successfully')
          expect(json).to have_key('bet_slip_id')
        end

        it "calculates total odds correctly" do
          post "/api/v1/betslips", params: valid_params, headers: auth_headers
          bet_slip = BetSlip.last

          expect(bet_slip.odds).to eq(2.5)
        end

        it "calculates win amount correctly" do
          post "/api/v1/betslips", params: valid_params, headers: auth_headers
          bet_slip = BetSlip.last

          expect(bet_slip.win_amount).to eq(2500.0)
        end

        context "with multiple bets (accumulator)" do
          let(:multi_bet_params) do
            {
              stake: 1000,
              bets: [
                {
                  fixture_id: fixture.id,
                  market_identifier: '1',
                  outcome: 'Home Win',
                  outcome_id: '1',
                  odd: 2.0,
                  specifier: nil,
                  bet_type: 'PreMatch'
                },
                {
                  fixture_id: Fabricate(:fixture).id,
                  market_identifier: '1',
                  outcome: 'Home Win',
                  outcome_id: '1',
                  odd: 1.5,
                  specifier: nil,
                  bet_type: 'PreMatch'
                }
              ]
            }
          end

          it "multiplies odds correctly" do
            post "/api/v1/betslips", params: multi_bet_params, headers: auth_headers
            bet_slip = BetSlip.last

            expect(bet_slip.odds).to eq(3.0) # 2.0 * 1.5
            expect(bet_slip.win_amount).to eq(3000.0) # 1000 * 3.0
          end

          it "creates multiple bets" do
            expect {
              post "/api/v1/betslips", params: multi_bet_params, headers: auth_headers
            }.to change(Bet, :count).by(2)
          end

          it "sets correct bet_count" do
            post "/api/v1/betslips", params: multi_bet_params, headers: auth_headers
            bet_slip = BetSlip.last

            expect(bet_slip.bet_count).to eq(2)
          end
        end

        context "with slip bonus" do
          let!(:slip_bonus) do
            Fabricate(:slip_bonus, 
              min_accumulator: 3, 
              max_accumulator: 5, 
              multiplier: 10,
              status: 'Active'
            )
          end

          let(:bonus_params) do
            {
              stake: 1000,
              bets: [
                { fixture_id: fixture.id, market_identifier: '1', outcome: 'Win', outcome_id: '1', odd: 2.0, specifier: nil, bet_type: 'PreMatch' },
                { fixture_id: Fabricate(:fixture).id, market_identifier: '1', outcome: 'Win', outcome_id: '1', odd: 2.0, specifier: nil, bet_type: 'PreMatch' },
                { fixture_id: Fabricate(:fixture).id, market_identifier: '1', outcome: 'Win', outcome_id: '1', odd: 2.0, specifier: nil, bet_type: 'PreMatch' }
              ]
            }
          end

          it "applies bonus when bet count matches" do
            post "/api/v1/betslips", params: bonus_params, headers: auth_headers
            bet_slip = BetSlip.last

            win_amount = 8000.0 # 1000 * 2 * 2 * 2
            expected_bonus = (win_amount * 0.1).round(2) # 10% bonus
            
            expect(bet_slip.bonus).to eq(expected_bonus)
          end

          it "calculates payout including bonus" do
            post "/api/v1/betslips", params: bonus_params, headers: auth_headers
            bet_slip = BetSlip.last

            win_amount = 8000.0
            bonus = (win_amount * 0.1).round(2)
            expected_payout = (bonus + win_amount).round(2)

            expect(bet_slip.payout).to eq(expected_payout)
          end

          it "calculates tax correctly" do
            post "/api/v1/betslips", params: bonus_params, headers: auth_headers
            bet_slip = BetSlip.last

            win_amount = 8000.0
            bonus = (win_amount * 0.1).round(2)
            expected_tax = (bonus + win_amount) * 0.15

            expect(bet_slip.tax).to eq(expected_tax)
          end
        end

        context "without applicable bonus" do
          it "sets bonus to 0" do
            post "/api/v1/betslips", params: valid_params, headers: auth_headers
            bet_slip = BetSlip.last

            expect(bet_slip.bonus).to eq(0.0)
          end
        end
      end

      context "with invalid parameters" do
        context "when stake is below minimum" do
          it "returns error message" do
            params = valid_params.merge(stake: 0.5)
            post "/api/v1/betslips", params: params, headers: auth_headers

            expect(response).to have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['message']).to eq('Amount should be between 1 UGX and 4,000,000 UGX')
          end

          it "does not create bet slip" do
            params = valid_params.merge(stake: 0.5)
            expect {
              post "/api/v1/betslips", params: params, headers: auth_headers
            }.not_to change(BetSlip, :count)
          end
        end

        context "when stake is above maximum" do
          it "returns error message" do
            params = valid_params.merge(stake: 5000000)
            post "/api/v1/betslips", params: params, headers: auth_headers

            expect(response).to have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['message']).to eq('Amount should be between 1 UGX and 4,000,000 UGX')
          end
        end

        context "when user has insufficient balance" do
          let(:poor_user) { Fabricate(:user, balance: 500.0) }
          let(:poor_user_token) { JWT.encode({ sub: poor_user.id, exp: 24.hours.from_now.to_i }, ENV['DEVISE_JWT_SECRET_KEY'], 'HS256') }
          let(:poor_user_headers) { { 'Authorization' => "Bearer #{poor_user_token}" } }

          it "returns insufficient balance error" do
            post "/api/v1/betslips", params: valid_params, headers: poor_user_headers

            expect(response).to have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['message']).to eq('Insufficient balance')
          end

          it "does not create bet slip" do
            expect {
              post "/api/v1/betslips", params: valid_params, headers: poor_user_headers
            }.not_to change(BetSlip, :count)
          end

          it "does not deduct from user balance" do
            expect {
              post "/api/v1/betslips", params: valid_params, headers: poor_user_headers
              poor_user.reload
            }.not_to change { poor_user.balance }
          end
        end
      end

      # context "transaction rollback on error" do
      #   it "rolls back all changes if bet creation fails" do
      #     allow_any_instance_of(Bet).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)

      #     expect {
      #       post "/api/v1/betslips", params: valid_params, headers: auth_headers
      #     }.to raise_error(ActiveRecord::RecordInvalid)

      #     user.reload
      #     expect(user.balance).to eq(10000.0) # Balance not changed
      #     expect(BetSlip.count).to eq(0)
      #     expect(Transaction.count).to eq(0)
      #   end
      # end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        post "/api/v1/betslips", params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end

      it "does not create bet slip" do
        expect {
          post "/api/v1/betslips", params: valid_params
        }.not_to change(BetSlip, :count)
      end
    end
  end
end
