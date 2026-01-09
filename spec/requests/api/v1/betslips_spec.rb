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
      let!(:market) { Fabricate(:pre_market, fixture: fixture, market_identifier: '1', specifier: nil, odds: { '1' => {odd: 2.5, outcome_id: '1'}, 'X' => {odd: 3.0, outcome_id: 'X'}, '2' => {odd: 2.8, outcome_id: '2'} }) }
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
                bet_type: { type: :string, enum: ['PreMatch', 'Live'] },
                bonus: { type: :boolean  } 
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

  path '/api/v1/betslips/{id}/cashout_offer' do
    parameter name: :id, in: :path, type: :integer, description: 'Betslip ID'

    get 'Gets cashout offer for a betslip' do
      tags 'Betslips'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'

      let(:Authorization) { auth_headers['Authorization'] }
      let(:fixture) { Fabricate(:fixture) }
      let(:betslip) { Fabricate(:bet_slip, user: user, status: 'Active', stake: 1000, payout: 5000) }
      let!(:bet) { Fabricate(:bet, bet_slip: betslip, user: user, fixture: fixture, status: 'Active', odds: 2.5, market_identifier: '1', outcome: '1', specifier: nil, bet_type: 'Live') }
      let!(:live_market) { Fabricate(:live_market, fixture: fixture, market_identifier: '1', specifier: nil, status: 'active', odds: { '1' => { 'odd' => 2.5, 'outcome_id' => '1' } }) }
      let(:id) { betslip.id }

      response '200', 'cashout offer available' do
        schema type: :object,
          properties: {
            available: { type: :boolean, example: true },
            cashout_value: { type: :number, example: 4000.50, description: 'Current cashout value in UGX' },
            potential_win: { type: :number, example: 5000.00, description: 'Original potential payout' },
            stake: { type: :number, example: 1000.00, description: 'Original stake' },
            current_odds: { type: :number, example: 2.5, description: 'Current accumulator odds' }
          },
          required: ['available']
        run_test!
      end

      response '200', 'cashout offer unavailable' do
        let(:betslip) { Fabricate(:bet_slip, user: user, status: 'Closed', stake: 1000, payout: 5000) }

        schema type: :object,
          properties: {
            available: { type: :boolean, example: false },
            reason: { type: :string, example: 'Bet slip already settled' },
            cashout_value: { type: :number, example: 0 },
            potential_win: { type: :number, example: 5000.00 },
            stake: { type: :number, example: 1000.00 }
          }
        run_test!
      end

      response '404', 'bet slip not found' do
        let(:id) { 999999 }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        run_test!
      end
    end
  end

  path '/api/v1/betslips/{id}/cashout' do
    parameter name: :id, in: :path, type: :integer, description: 'Betslip ID'

    post 'Executes cashout for a betslip' do
      tags 'Betslips'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'

      let(:Authorization) { auth_headers['Authorization'] }
      let(:fixture) { Fabricate(:fixture) }
      let(:betslip) { Fabricate(:bet_slip, user: user, status: 'Active', stake: 1000, payout: 5000) }
      let!(:bet) { Fabricate(:bet, bet_slip: betslip, user: user, fixture: fixture, status: 'Active', odds: 2.5, market_identifier: '1', outcome: '1', specifier: nil, bet_type: 'Live') }
      let!(:live_market) { Fabricate(:live_market, fixture: fixture, market_identifier: '1', specifier: nil, status: 'active', odds: { '1' => { 'odd' => 2.5, 'outcome_id' => '1' } }) }
      let(:id) { betslip.id }

      response '200', 'cashout successful' do
        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'Bet cashed out successfully' },
            cashout_value: { type: :number, example: 4000.50, description: 'Gross cashout value before tax' },
            new_balance: { type: :number, example: 13500.75, description: 'User balance after cashout' }
          },
          required: ['success', 'message', 'cashout_value', 'new_balance']
        run_test!
      end

      response '422', 'cashout unavailable' do
        let(:betslip) { Fabricate(:bet_slip, user: user, status: 'Closed', stake: 1000, payout: 5000) }

        schema type: :object,
          properties: {
            success: { type: :boolean, example: false },
            error: { type: :string, example: 'Bet slip already settled' }
          }
        run_test!
      end

      response '404', 'bet slip not found' do
        let(:id) { 999999 }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
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

        puts "Response JSON: #{json.inspect}"
        
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
    let!(:fixture) { Fabricate(:fixture) }
    let!(:market) { Fabricate(:pre_market, fixture: fixture, market_identifier: '1', specifier: nil, odds: { '1' => {odd: 2.5, outcome_id: '1'}, 'X' => {odd: 3.0, outcome_id: 'X'}, '2' => {odd: 2.8, outcome_id: '2'} }) }  
    let(:valid_params) do
      {
        stake: 1000,
        bets: [
          {
            fixture_id: fixture.id,
            market_identifier: '1',
            outcome_desc: 'Home Win',
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
        
        context "with same game bets" do
          let!(:same_game_fixture) { Fabricate(:fixture, event_id: SecureRandom.uuid, league_id: SecureRandom.uuid) }
          let!(:market1) do
            market = Fabricate.build(:pre_market, market_identifier: '1', specifier: nil, odds: { '1' => {'odd' => 2.0, 'outcome_id' => '1'} })
            market.fixture_id = same_game_fixture.id
            market.save!
            market
          end
          let!(:market2) do
            market = Fabricate.build(:pre_market, market_identifier: '10', specifier: nil, odds: { 'Over 2.5' => {'odd' => 3.0, 'outcome_id' => '1'} })
            market.fixture_id = same_game_fixture.id
            market.save!
            market
          end
         

          let(:same_game_params) do
            {
              stake: 5000,
              bets: [
                {
                  fixture_id: same_game_fixture.id,
                  market_identifier: '1',
                  outcome_desc: 'Home Win',
                  outcome_id: '1',
                  odd: 2.0,
                  specifier: nil,
                  bet_type: 'PreMatch'
                },
                {
                  fixture_id: same_game_fixture.id,
                  market_identifier: '10',
                  outcome_desc: 'Over 2.5',
                  outcome_id: '1',
                  odd: 3.0,
                  specifier: nil,
                  bet_type: 'PreMatch'
                }
              ]
            }
          end

          it "reduces odds for same game bets" do
            # puts "Fixture ID: #{fixture.id}"
            # puts "Market1 - fixture_id: #{market1.fixture_id}, market_identifier: #{market1.market_identifier}, specifier: #{market1.specifier.inspect}"
            # puts "Market2 - fixture_id: #{market2.fixture_id}, market_identifier: #{market2.market_identifier}, specifier: #{market2.specifier.inspect}"
            # puts "market1 odds: #{market1.odds}, market2 odds: #{market2.odds}"
            # # inspect the markets
            # puts "Market1 Odds: #{market1.odds}"
            # puts "Market2 Odds: #{market2.odds}"

            # puts "market1 odds: #{market1.odds}, market2 odds: #{market2.odds}"
            post "/api/v1/betslips", params: same_game_params, headers: auth_headers
            # puts "Same game response: #{response.body}"
            bet_slip = BetSlip.last
            # Odds should be reduced by 10%
            expect(bet_slip.odds).to eq((2.0 * 0.9 * 3.0 * 0.9).round(2))
          end

          it "rejects if stake is below same game minimum" do
            params = same_game_params.merge(stake: 1000)
            post "/api/v1/betslips", params: params, headers: auth_headers
            expect(response).to have_http_status(:bad_request).or have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['message']).to match(/Amount should be between/)
          end

          it "rejects if stake is above same game maximum" do
            params = same_game_params.merge(stake: 200_000)
            post "/api/v1/betslips", params: params, headers: auth_headers
            expect(response).to have_http_status(:bad_request).or have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['message']).to match(/Amount should be between/)
          end

          it "rejects if market is not accepted for same game" do
            # Use a market_identifier not in SAME_GAME_ACCEPETED_MARKETS
            bad_params = same_game_params.dup
            bad_params[:bets][1][:market_identifier] = '99'
            post "/api/v1/betslips", params: bad_params, headers: auth_headers
            expect(response).to have_http_status(:bad_request).or have_http_status(:bad_request)
            json = JSON.parse(response.body)
            expect(json['message']).to match(/Same game bets are only allowed/)
          end
        end


        context "with multiple bets (accumulator)" do
          let(:multi_bet_params) do
            {
              stake: 1000,
              bets: [
                {
                  fixture_id: fixture.id,
                  market_identifier: '1',
                  outcome_desc: 'Home Win',
                  outcome_id: '1',
                  odd: 2.50,
                  specifier: nil,
                  bet_type: 'PreMatch'
                },
                {
                  fixture_id: Fabricate(:fixture).id,
                  market_identifier: '1',
                  outcome_desc: 'Home Win',
                  outcome_id: '1',
                  odd: 1.5,
                  specifier: nil,
                  bet_type: 'PreMatch'
                }
              ]
            }
          end

        #  create the supporting pre_market for the second bet
          before do
            second_fixture = Fixture.find(multi_bet_params[:bets][1][:fixture_id])
            Fabricate(:pre_market, fixture: second_fixture, market_identifier: '1', specifier: nil, odds: { '1' => {odd: 1.5, outcome_id: '1'}, 'X' => {odd: 2.5, outcome_id: 'X'}, '2' => {odd: 3.0, outcome_id: '2'} })
          end

          it "multiplies odds correctly" do
            post "/api/v1/betslips", params: multi_bet_params, headers: auth_headers
            bet_slip = BetSlip.last

            expect(bet_slip.odds).to eq(3.75)
            expect(bet_slip.win_amount).to eq(3750.0) # 1000 * 2.5 * 1.5
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
                { fixture_id: fixture.id, market_identifier: '1', outcome_desc: 'Win', outcome_id: '1', odd: 2.0, specifier: nil, bet_type: 'PreMatch' },
                { fixture_id: Fabricate(:fixture).id, market_identifier: '1', outcome_desc: 'Win', outcome_id: '1', odd: 2.0, specifier: nil, bet_type: 'PreMatch' },
                { fixture_id: Fabricate(:fixture).id, market_identifier: '1', outcome_desc: 'Win', outcome_id: '1', odd: 2.0, specifier: nil, bet_type: 'PreMatch' }
              ]
            }
          end

          before do
            # Update the first market to match the expected odd of 2.0
            market.update(odds: { '1' => {odd: 2.0, outcome_id: '1'}, 'X' => {odd: 3.0, outcome_id: 'X'}, '2' => {odd: 2.8, outcome_id: '2'} })

            # Create markets for the 2nd and 3rd bets
            [1, 2].each do |index|
              fixture_id = bonus_params[:bets][index][:fixture_id]
              fixture = Fixture.find(fixture_id)
              Fabricate(:pre_market, fixture: fixture, market_identifier: '1', specifier: nil, odds: { '1' => {odd: 2.0, outcome_id: '1'}, 'X' => {odd: 3.0, outcome_id: 'X'}, '2' => {odd: 4.0, outcome_id: '2'} })
            end
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
            expected_tax = (bonus + win_amount) * BetSlip::TAX_RATE

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
            expect(json['message']).to eq('Amount should be between 1 UGX and 3000000 UGX')
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
            expect(json['message']).to eq('Amount should be between 1 UGX and 3000000 UGX')
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

      context "when the users activates bonus flag" do
        it "uses bonus balance to place bet" do
          bonus_user = Fabricate(:user, balance: 500.0)
          user_bonus = Fabricate(:user_bonus, user: bonus_user, amount: 10000.0, status: 'Active', expires_at: 1.day.from_now)
          bonus_user_token = JWT.encode({ sub: bonus_user.id, exp: 24.hours.from_now.to_i }, ENV['DEVISE_JWT_SECRET_KEY'], 'HS256')
          bonus_user_headers = { 'Authorization' => "Bearer #{bonus_user_token}" }

          params = valid_params.merge(bonus: true)

          expect {
            post "/api/v1/betslips", params: params, headers: bonus_user_headers
            puts "Bonus Bet Slip Response: #{response.body}"
            bonus_user.reload
          }.to change { bonus_user.balance }.by(0.0)
          .and change { user_bonus.reload.status }
          .and change(BetSlip, :count).by(1)
          
          
          # print response for debugging
          # puts "Bonus Bet Slip Response: #{response.body}"
          expect(response).to have_http_status(:created)
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Bet Slip created successfully')
        end
      end
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

  describe "GET /api/v1/betslips/:id/cashout_offer" do
    let(:fixture) { Fabricate(:fixture) }
    let(:betslip) { Fabricate(:bet_slip, user: user, status: 'Active', stake: 1000, payout: 5000, odds: 2.5) }
    let!(:bet) { Fabricate(:bet, bet_slip: betslip, user: user, fixture: fixture, status: 'Active', odds: 2.5, market_identifier: '1', outcome: '1', specifier: nil, bet_type: 'Live') }

    context "when user is authenticated" do
      context "when cashout is available" do
        let!(:live_market) { Fabricate(:live_market, fixture: fixture, market_identifier: '1', specifier: nil, status: 'active', odds: { '1' => { 'odd' => 2.5, 'outcome_id' => '1' } }) }

        it "returns http success" do
          get "/api/v1/betslips/#{betslip.id}/cashout_offer", headers: auth_headers
          expect(response).to have_http_status(:success)
        end

        it "returns cashout offer with available true" do
          get "/api/v1/betslips/#{betslip.id}/cashout_offer", headers: auth_headers
          json = JSON.parse(response.body)

          expect(json['available']).to eq(true)
          expect(json).to have_key('cashout_value')
          expect(json).to have_key('potential_win')
          expect(json).to have_key('stake')
          expect(json).to have_key('current_odds')
        end

        it "returns correct stake and potential win" do
          get "/api/v1/betslips/#{betslip.id}/cashout_offer", headers: auth_headers
          json = JSON.parse(response.body)

          expect(json['stake']).to eq(1000.0)
          expect(json['potential_win']).to eq(5000.0)
        end
      end

      context "when bet slip is already settled" do
        let(:settled_betslip) { Fabricate(:bet_slip, user: user, status: 'Closed', result: 'Win', stake: 1000, payout: 5000) }

        it "returns cashout unavailable" do
          get "/api/v1/betslips/#{settled_betslip.id}/cashout_offer", headers: auth_headers
          json = JSON.parse(response.body)

          expect(json['available']).to eq(false)
          expect(json['reason']).to eq('Bet slip already settled')
          expect(json['cashout_value']).to eq(0)
        end
      end

      context "when markets are not available" do
        it "returns cashout unavailable" do
          get "/api/v1/betslips/#{betslip.id}/cashout_offer", headers: auth_headers
          json = JSON.parse(response.body)

          expect(json['available']).to eq(false)
          expect(json['reason']).to match(/no*.*available/i)
        end
      end

      context "when bet slip does not exist" do
        it "returns not found" do
          get "/api/v1/betslips/999999/cashout_offer", headers: auth_headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        get "/api/v1/betslips/#{betslip.id}/cashout_offer"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /api/v1/betslips/:id/cashout" do
    let(:fixture) { Fabricate(:fixture) }
    let(:betslip) { Fabricate(:bet_slip, user: user, status: 'Active', stake: 1000, payout: 5000, odds: 2.5) }
    let!(:bet) { Fabricate(:bet, bet_slip: betslip, user: user, fixture: fixture, status: 'Active', odds: 2.5, market_identifier: '1', outcome: '1', specifier: nil, bet_type: 'Live') }

    context "when user is authenticated" do
      context "when cashout is available" do
        let!(:live_market) { Fabricate(:live_market, fixture: fixture, market_identifier: '1', specifier: nil, status: 'active', odds: { '1' => { 'odd' => 2.5, 'outcome_id' => '1' } }) }

        it "returns http success" do
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          expect(response).to have_http_status(:success)
        end

        it "returns success response with cashout details" do
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          json = JSON.parse(response.body)

          expect(json['success']).to eq(true)
          expect(json['message']).to eq('Bet cashed out successfully')
          expect(json).to have_key('cashout_value')
          expect(json).to have_key('new_balance')
        end

        it "updates bet slip status to Closed" do
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          betslip.reload

          expect(betslip.status).to eq('Closed')
          expect(betslip.result).to eq('Win')
        end

        it "closes all associated bets" do
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          bet.reload

          expect(bet.status).to eq('Closed')
          expect(bet.result).to eq('Win')
        end

        it "updates user balance" do
          initial_balance = user.balance
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          user.reload

          expect(user.balance).to be > initial_balance
        end

        it "creates a transaction record" do
          expect {
            post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          }.to change(Transaction, :count).by(1)
        end

        it "stores cashout_value and cashout_at" do
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          betslip.reload

          expect(betslip.cashout_value).to be > 0
          expect(betslip.cashout_at).not_to be_nil
        end

        it "calculates tax correctly" do
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          betslip.reload

          # Tax should be on net winnings only
          net_winnings = betslip.cashout_value - betslip.stake
          expected_tax = net_winnings > 0 ? (net_winnings * BetSlip::TAX_RATE) : 0

          expect(betslip.tax).to eq(expected_tax)
        end
      end

      context "when bet slip is already settled" do
        let(:settled_betslip) { Fabricate(:bet_slip, user: user, status: 'Closed', result: 'Win', stake: 1000, payout: 5000) }

        it "returns unprocessable entity" do
          post "/api/v1/betslips/#{settled_betslip.id}/cashout", headers: auth_headers
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns error message" do
          post "/api/v1/betslips/#{settled_betslip.id}/cashout", headers: auth_headers
          json = JSON.parse(response.body)

          expect(json['success']).to eq(false)
          expect(json['error']).to eq('Bet slip already settled')
        end
      end

      context "when markets are not available" do
        it "returns unprocessable entity" do
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "does not update bet slip" do
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          betslip.reload

          expect(betslip.status).to eq('Active')
        end

        it "does not update user balance" do
          initial_balance = user.balance
          post "/api/v1/betslips/#{betslip.id}/cashout", headers: auth_headers
          user.reload

          expect(user.balance).to eq(initial_balance)
        end
      end

      context "when bet slip does not exist" do
        it "returns not found" do
          post "/api/v1/betslips/999999/cashout", headers: auth_headers
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "when user is not authenticated" do
      it "returns unauthorized status" do
        post "/api/v1/betslips/#{betslip.id}/cashout"
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end


end
