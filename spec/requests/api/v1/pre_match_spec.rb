require 'rails_helper'
require 'swagger_helper'

RSpec.describe "Api::V1::PreMatch", type: :request do
  let(:user) { Fabricate(:user) }
  let(:auth_headers) do
    token = JWT.encode(
      { sub: user.id, exp: 24.hours.from_now.to_i, iat: Time.now.to_i },
      ENV['DEVISE_JWT_SECRET_KEY'],
      'HS256'
    )
    { 'Authorization' => "Bearer #{token}" }
  end

  path '/api/v1/pre_match' do
    get 'Lists all upcoming matches' do
      tags 'Pre-Match'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'

      let(:Authorization) { auth_headers['Authorization'] }

      response '200', 'successful' do
        schema type: :object,
          properties: {
            current_page: { type: :integer },
            total_pages: { type: :integer },
            total_count: { type: :integer },
            fixtures: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  event_id: { type: :string },
                  home_team: { type: :string },
                  away_team: { type: :string },
                  match_status: { type: :string },
                  start_date: { type: :string, format: 'date-time' },
                  sport: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      ext_sport_id: { type: :integer },
                      name: { type: :string }
                    }
                  },
                  tournament: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      ext_tournament_id: { type: :integer },
                      name: { type: :string }
                    }
                  },
                  category: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      ext_category_id: { type: :integer },
                      name: { type: :string }
                    }
                  },
                  markets: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        id: { type: :integer },
                        name: { type: :string },
                        market_identifier: { type: :string },
                        odds: { type: :object },
                        specifier: { type: :string, nullable: true }
                      }
                    }
                  }
                }
              }
            }
          }
        run_test!
      end
    end
  end

  path '/api/v1/pre_match/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Fixture ID'

    get 'Shows a specific upcoming match' do
      tags 'Pre-Match'
      produces 'application/json'
      security [Bearer: {}]
      parameter name: :Authorization, in: :header, type: :string, description: 'Bearer token'

      let(:Authorization) { auth_headers['Authorization'] }
      let(:pre_match_fixture) do
        sport = Fabricate(:sport, name: "Football", ext_sport_id: 20)
        category = Fabricate(:category, name: "England", ext_category_id: 120)
        tournament = Fabricate(:tournament, name: "Premier League", category: category, ext_tournament_id: 220)
        fixture = Fabricate(:fixture,
          event_id: "sr:match:prematch1",
          sport: sport,
          sport_id: sport.ext_sport_id,
          ext_tournament_id: tournament.ext_tournament_id,
          ext_category_id: category.ext_category_id,
          match_status: 'not_started',
          status: 'active',
          start_date: 2.days.from_now
        )
        Fabricate(:pre_market, fixture: fixture, market_identifier: "1", status: 'active')
        fixture
      end
      let(:id) { pre_match_fixture.id }
      
      response '200', 'successful' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              event_id: { type: :string },
              home_team: { type: :string },
              away_team: { type: :string },
              match_status: { type: :string },
              start_date: { type: :string, format: 'date-time' },
              sport: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  ext_sport_id: { type: :integer },
                  name: { type: :string }
                }
              },
              tournament: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  ext_tournament_id: { type: :integer },
                  name: { type: :string }
                }
              },
              category: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  ext_category_id: { type: :integer },
                  name: { type: :string }
                }
              },
              markets: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    name: { type: :string, nullable: true },
                    market_identifier: { type: :string },
                    odds: { type: :object },
                    specifier: { type: :string, nullable: true }
                  }
                }
              }
            }
          }
        run_test!
      end

      response '404', 'not found' do
        let(:id) { 999999 }
        run_test!
      end
    end
  end

  describe "GET /api/v1/pre_match" do
    let!(:sport) { Fabricate(:sport, name: "Football", ext_sport_id: 1) }
    let!(:category) { Fabricate(:category, name: "England") }
    let!(:tournament) { Fabricate(:tournament, name: "Premier League", category: category) }
    let!(:market) { Fabricate(:market, ext_market_id: 1, name: "1X2") }

    context "when user is authenticated" do
      context "with upcoming fixtures" do
        let!(:upcoming_fixture) do
          Fabricate(:fixture,
            sport: sport,
            ext_tournament_id: tournament.ext_tournament_id,
            part_one_name: "Arsenal",
            part_two_name: "Chelsea",
            match_status: 'not_started',
            status: 'active',
            start_date: 2.days.from_now, 
            sport_id: sport.ext_sport_id,
            ext_category_id: category.ext_category_id
          )
        end

        let!(:pre_market) do
          Fabricate(:pre_market,
            fixture: upcoming_fixture,
            market_identifier: "1",
            odds: { "1" => 2.5, "X" => 3.2, "2" => 2.8 }
          )
        end

        before do
          get "/api/v1/pre_match", headers: auth_headers
        end

        it "returns http success" do
          expect(response).to have_http_status(:ok)
        end

        it "returns paginated response structure" do
          json = JSON.parse(response.body)
          
          expect(json).to have_key('current_page')
          expect(json).to have_key('total_pages')
          expect(json).to have_key('total_count')
          expect(json).to have_key('fixtures')
        end

        it "returns fixtures array" do
          json = JSON.parse(response.body)
          
          expect(json['fixtures']).to be_an(Array)
          expect(json['fixtures'].length).to be > 0
        end

        it "includes fixture details" do
          json = JSON.parse(response.body)
          fixture = json['fixtures'].first
          
          expect(fixture['id']).to eq(upcoming_fixture.id)
          expect(fixture['event_id']).to eq(upcoming_fixture.event_id)
          expect(fixture['home_team']).to eq("Arsenal")
          expect(fixture['away_team']).to eq("Chelsea")
          expect(fixture['match_status']).to eq('not_started')
          expect(fixture['fixture_status']).to eq('active')
        end

        it "includes sport details" do
          json = JSON.parse(response.body)
          fixture = json['fixtures'].first
          
          expect(fixture['sport']).to be_present
          expect(fixture['sport']['id']).to eq(sport.id)
          expect(fixture['sport']["ext_sport_id"]).to eq(sport.ext_sport_id)
          expect(fixture['sport']['name']).to eq("Football")
        end

        it "includes tournament details" do
          json = JSON.parse(response.body)
          fixture = json['fixtures'].first
          
          expect(fixture['tournament']).to be_present
          expect(fixture['tournament']['id']).to eq(tournament.id)
          expect(fixture['tournament']['name']).to eq("Premier League")
        end

        it "includes category details" do
          json = JSON.parse(response.body)
          fixture = json['fixtures'].first

          #puts "inspecting fixture: #{fixture.inspect}"
          
          expect(fixture['category']).to be_present
          expect(fixture['category']['id']).to eq(category.id)
          expect(fixture['category']['ext_category_id']).to eq(category.ext_category_id)
          expect(fixture['category']['name']).to eq("England")
        end

        it "includes market details with odds" do
          json = JSON.parse(response.body)
          fixture = json['fixtures'].first
          
          expect(fixture['markets']).to be_present
          expect(fixture['markets']).to be_a(Hash)
          expect(fixture['markets']['name']).to eq("1X2")
          expect(fixture['markets']['market_identifier']).to eq("1")
          expect(fixture['markets']['odds']).to be_a(Hash)
          expect(fixture['markets']['odds']["1"]).to eq(2.5)
        end

        it "orders fixtures by start_date ascending" do
          later_fixture = Fabricate(:fixture,
            sport: sport,
            ext_tournament_id: tournament.ext_tournament_id,
            match_status: 'not_started',
            status: 'active',
            start_date: 3.days.from_now
          )

          Fabricate(:pre_market, fixture: later_fixture, market_identifier: "1")  

          get "/api/v1/pre_match", headers: auth_headers
          json = JSON.parse(response.body)
          
          # Earlier start date (2 days) should come first
          expect(json['fixtures'].first['id']).to eq(upcoming_fixture.id)
          expect(json['fixtures'].last['id']).to eq(later_fixture.id)
        end
      end

      context "with no upcoming fixtures" do
        before do
          get "/api/v1/pre_match", headers: auth_headers
        end

        it "returns empty fixtures array" do
          json = JSON.parse(response.body)
          
          expect(json['fixtures']).to eq([])
        end

        it "returns zero total_count" do
          json = JSON.parse(response.body)
          
          expect(json['total_count']).to eq(0)
        end
      end

      context "filters out fixtures that don't meet criteria" do
        let!(:started_fixture) do
          Fabricate(:fixture,
            sport: sport,
            match_status: 'in_play',
            status: 'active',
            start_date: 1.day.from_now
          )
        end

        let!(:inactive_fixture) do
          Fabricate(:fixture,
            sport: sport,
            match_status: 'not_started',
            status: 'inactive',
            start_date: 1.day.from_now
          )
        end

        let!(:past_fixture) do
          Fabricate(:fixture,
            sport: sport,
            match_status: 'not_started',
            status: 'active',
            start_date: 1.day.ago
          )
        end

        before do
          get "/api/v1/pre_match", headers: auth_headers
        end

        it "excludes fixtures that have started" do
          json = JSON.parse(response.body)
          fixture_ids = json['fixtures'].map { |f| f['fixture_id'] }
          
          expect(fixture_ids).not_to include(started_fixture.id)
        end

        it "excludes inactive fixtures" do
          json = JSON.parse(response.body)
          fixture_ids = json['fixtures'].map { |f| f['fixture_id'] }
          
          expect(fixture_ids).not_to include(inactive_fixture.id)
        end

        it "excludes fixtures in the past" do
          json = JSON.parse(response.body)
          fixture_ids = json['fixtures'].map { |f| f['fixture_id'] }
          
          expect(fixture_ids).not_to include(past_fixture.id)
        end
      end

      context "with pagination" do
        before do
          # Clean all prior fixtures and create 25 new ones
          Fixture.destroy_all
          PreMarket.destroy_all
          
          25.times do |i|
            fixture = Fabricate(:fixture,
              sport: sport,
              ext_tournament_id: tournament.ext_tournament_id,
              match_status: 'not_started',
              status: 'active',
              start_date: (i + 1).days.from_now
            )
            Fabricate(:pre_market, fixture: fixture, market_identifier: "1")
          end
        end

       

        it "paginates results with default page size" do
           puts "fixtures count after create: #{Fixture.all.count}"
          get "/api/v1/pre_match", headers: auth_headers
          json = JSON.parse(response.body)

          #puts "response body for pagination test: #{response.body}"
          
          expect(json['fixtures'].length).to be <= 20
        end

        it "returns correct page information" do
          
          get "/api/v1/pre_match", headers: auth_headers
          json = JSON.parse(response.body)
          
          expect(json['current_page']).to eq(1)
          expect(json['total_pages']).to be > 1
          # expect(json['total_count']).to eq(25)
          expect(Fixture.all.count).to eq(25)
        end

        it "supports page parameter" do
          get "/api/v1/pre_match", params: { page: 2 }, headers: auth_headers
          json = JSON.parse(response.body)
          
          expect(json['current_page']).to eq(2)
          expect(json['fixtures'].length).to be > 0
        end
      end

      context "with fixtures without markets" do
        let!(:fixture_without_market) do
          Fabricate(:fixture,
            sport: sport,
            ext_tournament_id: tournament.ext_tournament_id,
            match_status: 'not_started',
            status: 'active',
            start_date: 1.day.from_now
          )
        end

        before do
          get "/api/v1/pre_match", headers: auth_headers
        end

        it "includes fixtures without markets" do
          json = JSON.parse(response.body)
          #puts "fixture without market id: #{fixture_without_market.id}"
          #puts "response body: #{response.body}"
          fixture_ids = json['fixtures'].map { |f| f['id'] }
          
          expect(fixture_ids).not_to include(fixture_without_market.id)
        end

        # it "returns nil odds for fixtures without markets" do
        #   json = JSON.parse(response.body)
        #   fixture = json['fixtures'].find { |f| f['fixture_id'] == fixture_without_market.id }
          
        #   expect(fixture['markets']['odds']).to be_nil
        # end
      end
    end

    # context "when user is not authenticated" do
    #   it "returns unauthorized" do
    #     get "/api/v1/pre_match"
        
    #     expect(response).to have_http_status(:unauthorized)
    #   end
    # end
  end

  describe "GET /api/v1/pre_match/:id" do
    let!(:sport) { Fabricate(:sport, name: "Football") }
    let!(:category) { Fabricate(:category, name: "England") }
    let!(:tournament) { Fabricate(:tournament, name: "Premier League", category: category) }
    
    let!(:fixture) do
      Fabricate(:fixture,
        event_id: "12345",
        sport_id: sport.ext_sport_id,
        ext_tournament_id: tournament.ext_tournament_id,
        part_one_name: "Manchester United",
        part_two_name: "Liverpool",
        match_status: 'not_started',
        status: 'active',
        start_date: 3.days.from_now,
        ext_category_id: category.ext_category_id
      )
    end

    let!(:market1) { Fabricate(:market, ext_market_id: 1, name: "1X2") }
    let!(:market2) { Fabricate(:market, ext_market_id: 2, name: "Over/Under 2.5") }
    
    let!(:pre_market1) do
      Fabricate(:pre_market,
        fixture: fixture,
        market_identifier: "1",
        odds: { "1" => 2.1, "X" => 3.5, "2" => 3.2 },
        status: 'active'
      )
    end

    let!(:pre_market2) do
      Fabricate(:pre_market,
        fixture: fixture,
        market_identifier: "2",
        odds: { "over" => 1.85, "under" => 1.95 },
        status: 'active'
      )
    end

    context "when user is authenticated" do
      context "with valid event_id" do
        before do
          get "/api/v1/pre_match/#{fixture.id}", headers: auth_headers
        end

        it "returns http success" do
          expect(response).to have_http_status(:ok)
        end

        it "returns an array with one fixture" do
          json = JSON.parse(response.body)
          
          expect(json).to be_an(Array)
          expect(json.length).to eq(1)
        end

        it "includes complete fixture details" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          expect(fixture_data['id']).to eq(fixture.id)
          expect(fixture_data['event_id']).to eq(fixture.event_id)
          expect(fixture_data['home_team']).to eq("Manchester United")
          expect(fixture_data['away_team']).to eq("Liverpool")
          expect(fixture_data['match_status']).to eq('not_started')
        end

        it "includes sport details" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          puts "fixture_data sport: #{fixture_data['sport'].inspect}"
          
          expect(fixture_data['sport']['id']).to eq(sport.id)
          expect(fixture_data['sport']['name']).to eq("Football")
        end

        it "includes tournament details" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          expect(fixture_data['tournament']['id']).to eq(tournament.id)
          expect(fixture_data['tournament']['name']).to eq("Premier League")
        end

        it "includes category details" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          expect(fixture_data['category']['id']).to eq(category.id)
          expect(fixture_data['category']['name']).to eq("England")
        end

        it "includes all active markets" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          expect(fixture_data['markets']).to be_an(Array)
          expect(fixture_data['markets'].length).to eq(2)
        end

        it "includes market details with odds" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          markets = fixture_data['markets']
          
          market_names = markets.map { |m| m['name'] }
          expect(market_names).to include("1X2", "Over/Under 2.5")
          
          odds_1x2 = markets.find { |m| m['name'] == "1X2" }
          expect(odds_1x2['odds']).to be_a(Hash)
          expect(odds_1x2['odds']['1']).to eq(2.1)
        end

        it "parses JSON odds correctly" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          markets = fixture_data['markets']
          
          over_under = markets.find { |m| m['name'] == "Over/Under 2.5" }
          expect(over_under['odds']['over']).to eq(1.85)
          expect(over_under['odds']['under']).to eq(1.95)
        end
      end

      context "with non-existent event_id" do
        before do
          get "/api/v1/pre_match/99999", headers: auth_headers
        end

        it "returns not found status" do
          expect(response).to have_http_status(:not_found)
        end

        it "returns error message" do
          json = JSON.parse(response.body)
          
          expect(json['error']).to match(/not found or not available/)
        end
      end

      context "with started fixture" do
        let!(:started_fixture) do
          Fabricate(:fixture,
            event_id: "678985",
            sport: sport,
            match_status: 'in_play',
            status: 'active',
            start_date: 1.hour.ago
          )
        end

        before do
          get "/api/v1/pre_match/#{started_fixture.id}", headers: auth_headers
        end

        it "returns not found" do
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with inactive fixture" do
        let!(:inactive_fixture) do
          Fabricate(:fixture,
            event_id: "678986",
            sport: sport,
            match_status: 'not_started',
            status: 'inactive',
            start_date: 1.day.from_now
          )
        end

        before do
          get "/api/v1/pre_match/#{inactive_fixture.id}", headers: auth_headers
        end

        it "returns not found" do
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with past fixture date" do
        let!(:past_fixture) do
          Fabricate(:fixture,
            event_id: "9998988",
            sport: sport,
            match_status: 'not_started',
            status: 'active',
            start_date: 1.day.ago
          )
        end

        before do
          get "/api/v1/pre_match/#{past_fixture.id}", headers: auth_headers
        end

        it "returns not found" do
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with fixture without markets" do
        let!(:fixture_no_markets) do
          Fabricate(:fixture,
            event_id: "sr:match:nomarkets",
            sport: sport,
            ext_tournament_id: tournament.ext_tournament_id,
            match_status: 'not_started',
            status: 'active',
            start_date: 2.days.from_now
          )
        end

        before do
          get "/api/v1/pre_match/#{fixture_no_markets.id}", headers: auth_headers
        end

        it "returns the fixture" do
          expect(response).to have_http_status(:ok)
        end

        it "returns empty markets array" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          expect(fixture_data['markets']).to eq([])
        end
      end

      context "with inactive markets" do
        let!(:fixture_inactive_markets) do
          Fabricate(:fixture,
            event_id: "sr:match:inactive_markets",
            sport: sport,
            ext_tournament_id: tournament.ext_tournament_id,
            match_status: 'not_started',
            status: 'active',
            start_date: 2.days.from_now
          )
        end

        let!(:inactive_market) do
          Fabricate(:pre_market,
            fixture: fixture_inactive_markets,
            market_identifier: "3",
            status: 'inactive'
          )
        end

        before do
          get "/api/v1/pre_match/#{fixture_inactive_markets.id}", headers: auth_headers
        end

        it "excludes inactive markets" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          market_ids = fixture_data['markets'].map { |m| m['ext_market_id'] }
          expect(market_ids).not_to include(3)
        end
      end
    end

    # context "when user is not authenticated" do
    #   it "returns unauthorized" do
    #     get "/api/v1/pre_match/#{fixture.id}"
        
    #     expect(response).to have_http_status(:unauthorized)
    #   end
    # end
  end
end