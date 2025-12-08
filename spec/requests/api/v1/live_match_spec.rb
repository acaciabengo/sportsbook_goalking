require 'rails_helper'
require 'swagger_helper'

RSpec.describe "Api::V1::LiveMatch", type: :request do
  let(:user) { Fabricate(:user) }
  let(:auth_headers) do
    token = JWT.encode(
      { sub: user.id, exp: 24.hours.from_now.to_i, iat: Time.now.to_i },
      ENV['DEVISE_JWT_SECRET_KEY'],
      'HS256'
    )
    { 'Authorization' => "Bearer #{token}" }
  end

  path '/api/v1/live_match' do
    get 'Lists all live matches' do
      tags 'Live Matches'
      produces 'application/json'
      security [Bearer: {}]

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

  path '/api/v1/live_match/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Fixture ID'

    get 'Shows a specific live match' do
      tags 'Live Matches'
      produces 'application/json'
      security [Bearer: {}]
      
      let(:live_fixture_for_show) do
        sport = Fabricate(:sport, name: "Football", ext_sport_id: 10)
        category = Fabricate(:category, name: "England", ext_category_id: 110)
        tournament = Fabricate(:tournament, name: "Premier League", category: category, ext_tournament_id: 210)
        fixture = Fabricate(:fixture,
          event_id: "sr:match:show1",
          sport: sport,
          sport_id: sport.ext_sport_id,
          ext_tournament_id: tournament.ext_tournament_id,
          ext_category_id: category.ext_category_id,
          match_status: 'in_play',
          status: '0',
          start_date: 1.hour.ago
        )
        Fabricate(:live_market, fixture: fixture, market_identifier: "1", status: 'active')
        fixture
      end
      let(:id) { live_fixture_for_show.id }

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

  describe "GET /api/v1/live_match" do
    let!(:live_sport) { Fabricate(:sport, name: "Football", ext_sport_id: 1) }
    let!(:live_category) { Fabricate(:category, name: "England", ext_category_id: 100) }
    let!(:live_tournament) { Fabricate(:tournament, name: "Premier League", category: live_category, ext_tournament_id: 200) }
    let!(:live_market) { Fabricate(:market, ext_market_id: 1, name: "1X2") }

    context "when user is authenticated" do
      context "with live fixtures" do
        let!(:live_fixture) do
          Fabricate(:fixture,
            event_id: "sr:match:live1",
            sport: live_sport,
            sport_id: live_sport.ext_sport_id,
            ext_tournament_id: live_tournament.ext_tournament_id,
            ext_category_id: live_category.ext_category_id,
            part_one_name: "Arsenal",
            part_two_name: "Chelsea",
            match_status: 'in_play',
            status: '0',
            start_date: 1.hour.ago
          )
        end

        let!(:live_market_record) do
          Fabricate(:live_market,
            fixture: live_fixture,
            market_identifier: "1",
            odds: { "1" => 2.5, "X" => 3.2, "2" => 2.8 },
            status: 'active'
          )
        end

        before do
          get "/api/v1/live_match", headers: auth_headers
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
          
          expect(fixture['id']).to eq(live_fixture.id)
          expect(fixture['event_id']).to eq(live_fixture.event_id)
          expect(fixture['home_team']).to eq("Arsenal")
          expect(fixture['away_team']).to eq("Chelsea")
          expect(fixture['match_status']).to eq('in_play')
          expect(fixture['fixture_status']).to eq('0')
        end

        it "includes sport details" do
          json = JSON.parse(response.body)
          fixture = json['fixtures'].first
          
          expect(fixture['sport']).to be_present
          expect(fixture['sport']['id']).to eq(live_sport.id)
          expect(fixture['sport']['name']).to eq("Football")
          expect(fixture['sport']['ext_sport_id']).to eq(1)
        end

        it "includes tournament details" do
          json = JSON.parse(response.body)
          fixture = json['fixtures'].first
          
          expect(fixture['tournament']).to be_present
          expect(fixture['tournament']['id']).to eq(live_tournament.id)
          expect(fixture['tournament']['name']).to eq("Premier League")
          expect(fixture['tournament']['ext_tournament_id']).to eq(200)
        end

        it "includes category details" do
          json = JSON.parse(response.body)
          fixture = json['fixtures'].first
          
          expect(fixture['category']).to be_present
          expect(fixture['category']['id']).to eq(live_category.id)
          expect(fixture['category']['name']).to eq("England")
          expect(fixture['category']['ext_category_id']).to eq(100)
        end

        it "includes market details with odds" do
          json = JSON.parse(response.body)
          fixture = json['fixtures'].first

          expect(fixture['markets']).to be_present
          expect(fixture['markets']).to be_an(Array)
          
          market = fixture['markets'].first
          expect(market['name']).to eq("1X2")
          expect(market['market_identifier']).to eq("1")
          expect(market['odds']).to be_a(Hash)
        end

        it "orders fixtures by start_date ascending" do
          # The existing live_fixture was created at 1.hour.ago
          # Create a later fixture to verify ordering
          later_fixture = Fabricate(:fixture,
            event_id: "sr:match:live2",
            sport: live_sport,
            sport_id: live_sport.ext_sport_id,
            ext_tournament_id: live_tournament.ext_tournament_id,
            ext_category_id: live_category.ext_category_id,
            match_status: 'in_play',
            status: '0',
            start_date: 30.minutes.ago
          )
          Fabricate(:live_market, fixture: later_fixture, market_identifier: "1", status: 'active')
          
          get "/api/v1/live_match", headers: auth_headers
          json = JSON.parse(response.body)
          
          # Earlier fixture (1 hour ago) should come first
          expect(json['fixtures'].first['id']).to eq(live_fixture.id)
          expect(json['fixtures'].last['id']).to eq(later_fixture.id)
        end
      end

      context "with no live fixtures" do
        before do
          get "/api/v1/live_match", headers: auth_headers
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
        let!(:not_started_fixture) do
          Fabricate(:fixture,
            event_id: "sr:match:notstarted",
            sport: live_sport,
            sport_id: live_sport.ext_sport_id,
            ext_tournament_id: live_tournament.ext_tournament_id,
            ext_category_id: live_category.ext_category_id,
            match_status: 'not_started',
            status: 'active',
            start_date: 1.day.from_now
          )
        end

        let!(:inactive_fixture) do
          Fabricate(:fixture,
            event_id: "sr:match:inactive",
            sport: live_sport,
            sport_id: live_sport.ext_sport_id,
            match_status: 'in_play',
            status: 'inactive',
            start_date: 1.hour.ago
          )
        end

        let!(:finished_fixture) do
          Fabricate(:fixture,
            event_id: "sr:match:finished",
            sport: live_sport,
            sport_id: live_sport.ext_sport_id,
            match_status: 'finished',
            status: 'active',
            start_date: 2.hours.ago
          )
        end

        before do
          get "/api/v1/live_match", headers: auth_headers
        end

        it "excludes fixtures that haven't started" do
          json = JSON.parse(response.body)
          fixture_ids = json['fixtures'].map { |f| f['id'] }
          
          expect(fixture_ids).not_to include(not_started_fixture.id)
        end

        it "excludes inactive fixtures" do
          json = JSON.parse(response.body)
          fixture_ids = json['fixtures'].map { |f| f['id'] }
          
          expect(fixture_ids).not_to include(inactive_fixture.id)
        end

        it "excludes finished fixtures" do
          json = JSON.parse(response.body)
          fixture_ids = json['fixtures'].map { |f| f['id'] }
          
          expect(fixture_ids).not_to include(finished_fixture.id)
        end
      end

      context "with pagination" do
        let(:pagination_sport) { Fabricate(:sport, name: "Football", ext_sport_id: 2) }
        let(:pagination_category) { Fabricate(:category, name: "Spain", ext_category_id: 101) }
        let(:pagination_tournament) { Fabricate(:tournament, name: "La Liga", category: pagination_category, ext_tournament_id: 201) }

        before do
          Fixture.destroy_all
          LiveMarket.destroy_all
          
          25.times do |i|
            fixture = Fabricate(:fixture,
              event_id: "sr:match:live#{i}",
              sport: pagination_sport,
              sport_id: pagination_sport.ext_sport_id,
              ext_tournament_id: pagination_tournament.ext_tournament_id,
              ext_category_id: pagination_category.ext_category_id,
              match_status: 'in_play',
              status: '0',
              start_date: (i + 1).hours.ago
            )
            Fabricate(:live_market, fixture: fixture, market_identifier: "1", status: 'active')
          end
        end

        it "paginates results with default page size" do
          get "/api/v1/live_match", headers: auth_headers
          json = JSON.parse(response.body)
          
          expect(json['fixtures'].length).to be <= 20
        end

        it "returns correct page information" do
          get "/api/v1/live_match", headers: auth_headers
          json = JSON.parse(response.body)
          
          expect(json['current_page']).to eq(1)
          expect(json['total_pages']).to be >= 2
          expect(json['total_count']).to eq(25)
        end

        it "supports page parameter" do
          get "/api/v1/live_match", params: { page: 2 }, headers: auth_headers
          json = JSON.parse(response.body)
          
          expect(json['current_page']).to eq(2)
          expect(json['fixtures'].length).to be > 0
        end
      end
    end
  end

  describe "GET /api/v1/live_match/:id" do
    let(:show_sport) { Fabricate(:sport, name: "Football", ext_sport_id: 3) }
    let(:show_category) { Fabricate(:category, name: "Germany", ext_category_id: 102) }
    let(:show_tournament) { Fabricate(:tournament, name: "Bundesliga", category: show_category, ext_tournament_id: 202) }
    
    let!(:fixture) do
      Fabricate(:fixture,
        event_id: "sr:match:12345",
        sport: show_sport,
        sport_id: show_sport.ext_sport_id,
        ext_tournament_id: show_tournament.ext_tournament_id,
        ext_category_id: show_category.ext_category_id,
        part_one_name: "Bayern Munich",
        part_two_name: "Borussia Dortmund",
        match_status: 'in_play',
        status: '0',
        start_date: 1.hour.ago
      )
    end

    let!(:market1) { Fabricate(:market, ext_market_id: 1, name: "1X2") }
    let!(:market2) { Fabricate(:market, ext_market_id: 2, name: "Over/Under 2.5") }
    
    let!(:live_market1) do
      Fabricate(:live_market,
        fixture: fixture,
        market_identifier: 1,
        odds: { "1" => 2.1, "X" => 3.5, "2" => 3.2 },
        status: 'active'
      )
    end

    let!(:live_market2) do
      Fabricate(:live_market,
        fixture: fixture,
        market_identifier: 2,
        odds: { "over" => 1.85, "under" => 1.95 },
        status: 'active'
      )
    end

    context "when user is authenticated" do
      context "with valid event_id" do
        before do
          get "/api/v1/live_match/#{fixture.id}", headers: auth_headers
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
          expect(fixture_data['home_team']).to eq("Bayern Munich")
          expect(fixture_data['away_team']).to eq("Borussia Dortmund")
          expect(fixture_data['match_status']).to eq('in_play')
        end

        it "includes sport details" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          expect(fixture_data['sport']['id']).to eq(show_sport.id)
          expect(fixture_data['sport']['name']).to eq("Football")
          expect(fixture_data['sport']['ext_sport_id']).to eq(3)
        end

        it "includes tournament details" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          expect(fixture_data['tournament']['id']).to eq(show_tournament.id)
          expect(fixture_data['tournament']['name']).to eq("Bundesliga")
          expect(fixture_data['tournament']['ext_tournament_id']).to eq(202)
        end

        it "includes category details" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          expect(fixture_data['category']['id']).to eq(show_category.id)
          expect(fixture_data['category']['name']).to eq("Germany")
          expect(fixture_data['category']['ext_category_id']).to eq(102)
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
          expect(markets).to be_an(Array)
          
          over_under = markets.find { |m| m['name'] == "Over/Under 2.5" }
          expect(over_under['odds']['over']).to eq(1.85)
          expect(over_under['odds']['under']).to eq(1.95)
        end
      end

      context "with non-existent event_id" do
        before do
          get "/api/v1/live_match/99999", headers: auth_headers
        end

        it "returns not found status" do
          expect(response).to have_http_status(:not_found)
        end

        it "returns error message" do
          json = JSON.parse(response.body)
          
          expect(json['error']).to match(/not found or not available/)
        end
      end

      context "with not started fixture" do
        let!(:not_started_fixture) do
          Fabricate(:fixture,
            event_id: "sr:match:notstarted",
            sport: show_sport,
            sport_id: show_sport.ext_sport_id,
            match_status: 'not_started',
            status: 'active',
            start_date: 1.day.from_now
          )
        end

        before do
          get "/api/v1/live_match/#{not_started_fixture.id}", headers: auth_headers
        end

        it "returns not found" do
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with inactive fixture" do
        let!(:inactive_fixture) do
          Fabricate(:fixture,
            event_id: "sr:match:inactive",
            sport: show_sport,
            sport_id: show_sport.ext_sport_id,
            match_status: 'in_play',
            status: 'inactive',
            start_date: 1.hour.ago
          )
        end

        before do
          get "/api/v1/live_match/#{inactive_fixture.id}", headers: auth_headers
        end

        it "returns not found" do
          expect(response).to have_http_status(:not_found)
        end
      end

      context "with fixture without markets" do
        let!(:fixture_no_markets) do
          Fabricate(:fixture,
            event_id: "sr:match:nomarkets",
            sport: show_sport,
            sport_id: show_sport.ext_sport_id,
            ext_tournament_id: show_tournament.ext_tournament_id,
            ext_category_id: show_category.ext_category_id,
            match_status: 'in_play',
            status: '0',
            start_date: 1.hour.ago
          )
        end

        before do
          get "/api/v1/live_match", headers: auth_headers
        end

        it "returns the fixture" do
          expect(response).to have_http_status(:ok)
        end

        it "returns empty markets array" do
          json = JSON.parse(response.body)
          fixtures = json['fixtures']
          fixture_data = fixtures.find { |f| f['id'] == fixture_no_markets.id }
          
          expect(fixture_data).to be_present
          expect(fixture_data['markets']).to eq([])
        end
      end

      context "with inactive markets" do
        let!(:fixture_inactive_markets) do
          Fabricate(:fixture,
            event_id: "90777",
            sport: show_sport,
            sport_id: show_sport.ext_sport_id,
            ext_tournament_id: show_tournament.ext_tournament_id,
            ext_category_id: show_category.ext_category_id,
            match_status: 'in_play',
            status: '0',
            start_date: 1.hour.ago
          )
        end

        let!(:inactive_market) do
          Fabricate(:live_market,
            fixture: fixture_inactive_markets,
            market_identifier: '3',
            status: 'inactive'
          )
        end

        let!(:active_market) do
          Fabricate(:live_market,
            fixture: fixture_inactive_markets,
            market_identifier: '1',
            status: 'active'
          )
        end

        before do
          get "/api/v1/live_match/#{fixture_inactive_markets.id}", headers: auth_headers
        end

        it "excludes inactive markets" do
          json = JSON.parse(response.body)
          fixture_data = json.first
          
          market_ids = fixture_data['markets'].map { |m| m['market_identifier'] }
          expect(market_ids).not_to include('3')
          expect(market_ids).to include('1')
        end
      end
    end
  end
end