require "rails_helper"

RSpec.describe BetBalancer do
  let(:client) { described_class.new }
  let(:base_url) { BetBalancer::BASE_URL }

  let(:default_params) do
    {
      bookmakerName: ENV["BET_BALANCER_BOOKMAKER_NAME"],
      key: ENV["BET_BALANCER_API_KEY"]
    }
  end

  before do
    ENV["BET_BALANCER_BOOKMAKER_NAME"] = "TestBookmaker"
    ENV["BET_BALANCER_API_KEY"] = "test_api_key_123"
  end

  describe "#initialize" do
    it "sets up the client with correct base URL" do
      expect(client.instance_variable_get(:@client)).to be_a(
        Faraday::Connection
      )
    end

    it "sets default params with bookmaker name and API key" do
      params = client.instance_variable_get(:@default_params)
      expect(params[:bookmakerName]).to eq("TestBookmaker")
      expect(params[:key]).to eq("test_api_key_123")
    end
  end

  describe "#get_sports" do
    let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <Sports>
          <Sport ID="1" Name="Football"/>
          <Sport ID="2" Name="Basketball"/>
        </Sports>
      XML

    let(:stubbed_request) do
      stub_request(:get, %r{#{base_url}/export/getSports*}).to_return(
        status: 200,
        body: xml_response,
        headers: {
          "Content-Type" => "application/xml"
        }
      )
    end

    before (:each) do
      stubbed_request
    end

    context "without sport_id" do
      it "fetches all sports" do
        status, result = client.get_sports

        expect(stubbed_request).to have_been_requested
        expect(result).to be_a(Nokogiri::XML::Document)
        expect(result.xpath("//Sport").count).to eq(2)
        expect(result.at_xpath("//Sport[@ID='1']/@Name").value).to eq(
          "Football"
        )
        expect(status).to eq(200)
      end
    end

    context "with sport_id" do
      it "fetches specific sport" do
        status, result = client.get_sports(sport_id: 1)

        expect(stubbed_request).to have_been_requested
        expect(result).to be_a(Nokogiri::XML::Document)
        expect(result.at_xpath("//Sport/@ID").value).to eq("1")
        expect(status).to eq(200)
      end
    end
  end

  describe "#get_categories" do
    let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <Categories>
          <Category ID="100" Name="Premier League"/>
          <Category ID="101" Name="La Liga"/>
        </Categories>
      XML

    let(:stubbed_request) do
      stub_request(:get, %r{#{base_url}/export/getCategories*}).to_return(
        status: 200,
        body: xml_response,
        headers: {
          "Content-Type" => "application/xml"
        }
      )
    end

    before (:each) do
      stubbed_request
    end

    context "without parameters" do
      it "fetches all categories" do
        status, data = client.get_categories

        expect(stubbed_request).to have_been_requested
        expect(data).to be_a(Nokogiri::XML::Document)
        expect(data.xpath("//Category").count).to eq(2)
        expect(status).to eq(200)
      end
    end

    context "with sport_id" do
      it "fetches categories for specific sport" do
        status, data = client.get_categories(sport_id: 1)

        expect(stubbed_request).to have_been_requested
        expect(data).to be_a(Nokogiri::XML::Document)
        expect(status).to eq(200)
      end
    end

    context "with sport_id and category_id" do
      it "fetches specific category" do
        status, data = client.get_categories(sport_id: 1, category_id: 100)
        expect(stubbed_request).to have_been_requested
        expect(data).to be_a(Nokogiri::XML::Document)
        expect(status).to eq(200)
      end
    end
  end

  describe "#get_tournaments" do
    let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <Tournaments>
          <Tournament ID="500" Name="World Cup 2024"/>
        </Tournaments>
      XML

    let(:stubbed_request) do
      stub_request(:get, %r{#{base_url}/export/getTournaments*}).to_return(
        status: 200,
        body: xml_response,
        headers: {
          "Content-Type" => "application/xml"
        }
      )
    end

    before (:each) do
      stubbed_request
    end
    it "fetches tournaments with all parameters" do
      status, result =
        client.get_tournaments(
          sport_id: 1,
          category_id: 100,
          tournament_id: 500
        )

      expect(stubbed_request).to have_been_requested
      expect(result).to be_a(Nokogiri::XML::Document)
      expect(result.at_xpath("//Tournament/@Name").value).to eq(
        "World Cup 2024"
      )
      expect(status).to eq(200)
    end
  end

  describe "#get_markets" do
    let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <MatchOdds>
          <Bet OddType=10>
            <Texts>
              <Text Language="en">
                <Value>Full Time</Value>
              </Text>
              <Text Language="fr">
                <Value>Full Time</Value>
              </Text>
            </Texts>
          </Bet>
              
        </MatchOdds>
      XML

    it "fetches markets" do
      stub =
        stub_request(:get, %r{#{base_url}/export/getMarkets*}).with(
          query: default_params
        ).to_return(
          status: 200,
          body: xml_response,
          headers: {
            "Content-Type" => "application/xml"
          }
        )

      status, result = client.get_markets

      expect(stub).to have_been_requested
      expect(result.xpath("//Bet").count).to eq(1)
      expect(status).to eq(200)
    end

    it "accepts optional filters" do
      stub =
        stub_request(:get, "#{base_url}/export/getMarkets").with(
          query: default_params.merge(sportId: 1, marketId: 10)
        ).to_return(
          status: 200,
          body: xml_response,
          headers: {
            "Content-Type" => "application/xml"
          }
        )

      status, result = client.get_markets(sport_id: 1, market_id: 10)

      expect(stub).to have_been_requested
      expect(result.xpath("//Bet").count).to eq(1)
      expect(status).to eq(200)
    end
  end

  describe "#get_matches" do
    let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <Match BetbalancerMatchID="109379">
          <Fixture>
            <Competitors>
              <Texts>
                <Text Type="1" ID="9373" SUPERID="9243">
                  <Value>1. FC BRNO</Value>
                </Text>
              </Texts>
              <Texts>
                <Text Type="2" ID="371400" SUPERID="1452">
                  <Value>FC SLOVACKO</Value>
                </Text>
              </Texts>
            </Competitors>
            <DateInfo>
              <MatchDate>2004-8-23T16:40:00</MatchDate>
            </DateInfo>
            <StatusInfo>
              <Off>0</Off> </StatusInfo>
            <NeutralGround>
              <Value>0</Value>
            </NeutralGround>
          </Fixture>
          <MatchOdds>
            <Bet OddsType="10">
              <Odds OutCome="1">2.15</Odds>
              <Odds OutCome="X">2.85</Odds>
              <Odds OutCome="2">2.9</Odds>
            </Bet>
            <Bet OddsType="18">
              <Odds OutCome="over {total}" SpecialBetValue="2.5">2.00</Odds>
              <Odds OutCome="under {total}" SpecialBetValue="2.5">1.75</Odds>
            </Bet>
          </MatchOdds>
          <Result>
            <ScoreInfo>
              <Score Type="FT">1:0</Score>
              <Score Type="HT">0:0</Score>
            </ScoreInfo>
          </Result>
          <BetResult>
            <W OddsType="10" OutComeId="100" OutCome="1"/> 
            
            <W OddsType="18" OutComeId="1" OutCome="C" Reason="NO_RESULT_ASSIGNABLE"/>
            
            <W OddsType="16" OutComeId="2" OutCome="competitor2" Status="W" VoidFactor="0.5"/>
          </BetResult>
        </Match>
        
      XML

    let(:stubbed_request) do
      stub_request(:get, %r{#{base_url}/export/getMatch*}).to_return(
        status: 200,
        body: xml_response,
        headers: {
          "Content-Type" => "application/xml"
        }
      )
    end

    before (:each) do
      stubbed_request
    end

    context "without parameters" do
      it "fetches all matches" do
        status, result = client.get_matches

        expect(stubbed_request).to have_been_requested
        expect(result.xpath("//Match").count).to eq(1)
        expect(status).to eq(200)
      end
    end

    context "with all parameters" do
      it "fetches filtered matches" do
        params =
          default_params.merge(
            sportId: 1,
            categoryId: 100,
            tournamentId: 500,
            marketId: 10,
            matchId: 109_379,
            dateFrom: "2024-01-01",
            dateTo: "2024-12-31",
            wantScore: true
          )

        status, result =
          client.get_matches(
            sport_id: 1,
            category_id: 100,
            tournament_id: 500,
            market_id: 10,
            match_id: 109_379,
            date_from: "2024-01-01",
            date_to: "2024-12-31",
            want_score: true
          )

        expect(stubbed_request).to have_been_requested
        expect(result.at_xpath("//Match/@BetbalancerMatchID").value).to eq(
          "109379"
        )
        expect(status).to eq(200)
      end
    end

    context "with date range" do
      it "fetches matches within date range" do
        status, result =
          client.get_matches(date_from: "2024-01-01", date_to: "2024-01-31")

        expect(stubbed_request).to have_been_requested
        expect(result.xpath("//Match").count).to eq(1)
        expect(status).to eq(200)
      end
    end

    context "with want_score flag" do
      it "includes scores in response" do
        status, result = client.get_matches(want_score: true)

        expect(stubbed_request).to have_been_requested
        expect(result.xpath("//Score").count).to eq(2)
        expect(status).to eq(200)
      end
    end
  end

  describe "error handling" do
    context "when API returns error" do
      before do
        stub_request(:get, %r{#{base_url}/export/getSports*}).to_raise(
          Faraday::ConnectionFailed.new("Connection refused")
        )
      end
      it "raises Faraday error for network issues" do
        expect { client.get_sports }.to raise_error(
          Faraday::ConnectionFailed,
          /Connection refused/
        )
      end
    end

    context "when API returns invalid XML" do
      before do
        stub_request(:get, %r{#{base_url}/export/getSports*}).to_return(
          status: 200,
          body: "Invalid XML {}",
          headers: {
            "Content-Type" => "application/xml"
          }
        )
      end
      it "handles parsing errors" do
        status, result = client.get_sports

        # Nokogiri will still parse but with errors
        expect(result).to be_a(Nokogiri::XML::Document)
        expect(result.errors).not_to be_empty
      end
    end

    context "when API returns 500 error" do
      it "handles server errors" do
        stub_request(:get, %r{#{base_url}/export/getSports*}).to_return(
          status: 500,
          body: "Internal Server Error"
        )

        # Currently doesn't handle HTTP errors - might want to add this
        expect { client.get_sports }.not_to raise_error
      end
    end
  end

  describe "parameter merging" do
    it "does not mutate default_params" do
      stub_request(:get, %r{#{base_url}/export/getCategories*}).to_return(
        status: 200,
        body: "<Categories></Categories>",
        headers: {
          "Content-Type" => "application/xml"
        }
      )

      original_params = client.instance_variable_get(:@default_params).dup

      client.get_categories(sport_id: 1, category_id: 100)

      current_params = client.instance_variable_get(:@default_params)
      expect(current_params).to eq(original_params)
    end
  end
end
