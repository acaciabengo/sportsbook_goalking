require "rails_helper"

RSpec.describe PreMatch::PullFixturesJob, type: :worker do
  let(:worker) { described_class.new }
  let(:bet_balancer) { instance_double(BetBalancer) }

  let(:xml_response) { <<~XML }
      <?xml version="1.0" encoding="UTF-8"?>
        <BetbalancerBetData>
          <Sports>
            <Sport BetbalancerSportID="1">
              <Texts>
                <Text Language="BET"><Value>Soccer</Value></Text>
                <Text Language="en"><Value>Football</Value></Text>
              </Texts>
              <Category BetbalancerCategoryID="10" IsoName="CZE">
                <Texts>
                  <Text Language="en"><Value>Czech Republic</Value></Text>
                </Texts>

                <Tournament BetbalancerTournamentID="100">
                  <Texts>
                    <Text Language="en"><Value>First League</Value></Text>
                  </Texts>
                  
                  <Match BetbalancerMatchID="109379">
                    <Fixture>
                      <Competitors>
                        <Texts>
                          <Text Type="1" ID="9373" SUPERID="9243">
                            <Text Language="en">
                              <Value>1. FC BRNO</Value>
                            </Text>
                          </Text>
                        </Texts>
                        <Texts>
                          <Text Type="2" ID="371400" SUPERID="1452">
                            <Text Language="en">
                              <Value>FC SLOVACKO</Value>
                            </Text>
                          </Text>
                        </Texts>
                      </Competitors>
                      <DateInfo>
                        <MatchDate>2004-8-23T16:40:00</MatchDate>
                      </DateInfo>
                      <StatusInfo>
                        <Off>0</Off>
                      </StatusInfo>
                    </Fixture>
                    
                    <MatchOdds>
                      <Bet OddsType="10">
                        <Odds OutCome="1">2.15</Odds>
                        <Odds OutCome="X">2.85</Odds>
                        <Odds OutCome="2">2.9</Odds>
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
                    </BetResult>
                    </Match>
                  
                </Tournament>
              </Category>
            </Sport>
          </Sports>
        </BetbalancerBetData>
      XML
  before do
    # stub_const("PreMatch::PullFixturesJob::ACCEPTED_SPORTS", [1])
    allow(BetBalancer).to receive(:new).and_return(bet_balancer)
    allow(bet_balancer).to receive(:get_matches).and_return([200, Nokogiri.XML(xml_response)])
  end

  describe "#perform" do
    context "when fixtures don't exist" do
      it "creates new fixtures from API data" do
        expect { worker.perform }.to change(Fixture, :count).by(1)

        fixture = Fixture.last
        expect(fixture).to have_attributes(
          event_id: "109379",
          sport_id: "1",
          ext_category_id: 10,
          ext_tournament_id: 100,
          part_one_id: "9373",
          part_one_name: "1. FC BRNO",
          part_two_id: "371400",
          part_two_name: "FC SLOVACKO",
          match_status: "not_started"
        )
      end

      it "creates pre-markets for the fixture" do
        expect { worker.perform }.to change(PreMarket, :count).by(1)

        pre_market = PreMarket.last
        expect(pre_market.market_identifier).to eq("10")
        expect(pre_market.status).to eq("active")

        odds = pre_market.odds
        expect(odds["1"]).to include("odd" => 2.15)
        expect(odds["X"]).to include("odd" => 2.85)
        expect(odds["2"]).to include("odd" => 2.9)
      end

      it "calls BetBalancer API for each sport" do
        worker.perform

        expect(bet_balancer).to have_received(:get_matches).at_least(:once)
      end
    end

    context "when fixture already exists" do
      let!(:existing_fixture) do
        Fabricate(:fixture, event_id: 109_379, sport_id: 1)
      end

      it "does not create duplicate fixtures" do
        expect { worker.perform }.not_to change(Fixture, :count)
      end

      it "does not create pre-markets for existing fixture" do
        expect { worker.perform }.not_to change(PreMarket, :count)
      end
    end

    context "when status is cancelled (Off=1)" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
            <BetbalancerBetData>
              <Sports>
                <Sport BetbalancerSportID="1">
                  <Texts>
                    <Text Language="BET"><Value>Soccer</Value></Text>
                    <Text Language="en"><Value>Football</Value></Text>
                  </Texts>
                  <Category BetbalancerCategoryID="10" IsoName="CZE">
                    <Texts>
                      <Text Language="en"><Value>Czech Republic</Value></Text>
                    </Texts>

                    <Tournament BetbalancerTournamentID="100">
                      <Texts>
                        <Text Language="en"><Value>First League</Value></Text>
                      </Texts>
                      
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
                            <Off>1</Off>
                          </StatusInfo>
                        </Fixture>
                        
                        <MatchOdds>
                          <Bet OddsType="10">
                            <Odds OutCome="1">2.15</Odds>
                            <Odds OutCome="X">2.85</Odds>
                            <Odds OutCome="2">2.9</Odds>
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
                        </BetResult>
                        </Match>
                      
                    </Tournament>
                  </Category>
                </Sport>
              </Sports>
            </BetbalancerBetData>
          XML

      it "sets fixture status to cancelled" do
        worker.perform

        fixture = Fixture.last
        expect(fixture.match_status).to eq("not_started")
        expect(fixture.status).to eq("1")
      end
    end

    context "with multiple categories" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en"><Value>Football</Value></Text>
                </Texts>
                <Category BetbalancerCategoryID="100" IsoName="CZE">
                  <Texts>
                    <Text Language="en"><Value>Czech Republic</Value></Text>
                  </Texts>
                  <Tournament BetbalancerTournamentID="500">
                    <Texts>
                      <Text Language="en"><Value>First League</Value></Text>
                    </Texts>
                    <Match BetbalancerMatchID="109379">
                      <Fixture>
                        <Competitors>
                          <Texts>
                            <Text Type="1" ID="9373">
                              <Value>Team A</Value>
                            </Text>
                          </Texts>
                          <Texts>
                            <Text Type="2" ID="9374">
                              <Value>Team B</Value>
                            </Text>
                          </Texts>
                        </Competitors>
                        <DateInfo>
                          <MatchDate>2024-08-23T16:40:00</MatchDate>
                        </DateInfo>
                        <StatusInfo>
                          <Off>1</Off>
                        </StatusInfo>
                      </Fixture>
                      <MatchOdds>
                        <Bet OddsType="10">
                          <Odds OutCome="1" OutcomeID="1">2.15</Odds>
                        </Bet>
                      </MatchOdds>
                    </Match>
                  </Tournament>
                </Category>
                <Category BetbalancerCategoryID="101" IsoName="ESP">
                  <Texts>
                    <Text Language="en"><Value>Spain</Value></Text>
                  </Texts>
                  <Tournament BetbalancerTournamentID="501">
                    <Texts>
                      <Text Language="en"><Value>La Liga</Value></Text>
                    </Texts>
                    <Match BetbalancerMatchID="109380">
                      <Fixture>
                        <Competitors>
                          <Texts>
                            <Text Type="1" ID="9375">
                              <Value>Team C</Value>
                            </Text>
                          </Texts>
                          <Texts>
                            <Text Type="2" ID="9376">
                              <Value>Team D</Value>
                            </Text>
                          </Texts>
                        </Competitors>
                        <DateInfo>
                          <MatchDate>2024-08-24T18:00:00</MatchDate>
                        </DateInfo>
                        <StatusInfo>
                          <Off>1</Off>
                        </StatusInfo>
                      </Fixture>
                      <MatchOdds>
                        <Bet OddsType="11">
                          <Odds OutCome="Over" OutcomeID="4" SpecialBetValue="2.5">1.85</Odds>
                        </Bet>
                      </MatchOdds>
                    </Match>
                  </Tournament>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "creates fixtures for all categories" do
        expect { worker.perform }.to change(Fixture, :count).by(2)
      end

      it "creates pre-markets for all fixtures" do
        expect { worker.perform }.to change(PreMarket, :count).by(2)
      end
    end

    context "with multiple odds types (markets)" do
      let(:xml_response) { <<~XML }
      <?xml version="1.0" encoding="UTF-8"?>
      <BetbalancerBetData>
        <Sports>
          <Sport BetbalancerSportID="1">
            <Texts>
              <Text Language="en"><Value>Football</Value></Text>
            </Texts>
            <Category BetbalancerCategoryID="100" IsoName="CZE">
              <Texts>
                <Text Language="en"><Value>Czech Republic</Value></Text>
              </Texts>
              <Tournament BetbalancerTournamentID="500">
                <Texts>
                  <Text Language="en"><Value>First League</Value></Text>
                </Texts>
                <Match BetbalancerMatchID="109379">
                  <Fixture>
                    <Competitors>
                      <Texts>
                        <Text Type="1" ID="9373">
                          <Value>Team A</Value>
                        </Text>
                      </Texts>
                      <Texts>
                        <Text Type="2" ID="9374">
                          <Value>Team B</Value>
                        </Text>
                      </Texts>
                    </Competitors>
                    <DateInfo>
                      <MatchDate>2024-08-23T16:40:00</MatchDate>
                    </DateInfo>
                    <StatusInfo>
                      <Off>1</Off>
                    </StatusInfo>
                  </Fixture>
                  <MatchOdds>
                    <Bet OddsType="10">
                      <Odds OutCome="1" OutcomeId="1">2.15</Odds>
                    </Bet>
                    <Bet OddsType="11">
                      <Odds OutCome="Over" OutcomeId="2" SpecialBetValue="2.5">1.85</Odds>
                    </Bet>
                  </MatchOdds>
                </Match>
              </Tournament>
            </Category>
          </Sport>
        </Sports>
      </BetbalancerBetData>
    XML

      it "creates multiple pre-markets for the same fixture" do
        expect { worker.perform }.to change(PreMarket, :count).by(2)

        market_identifiers = PreMarket.pluck(:market_identifier)
        # Depending on how you store market_identifier (string vs integer)
        expect(market_identifiers).to contain_exactly("10", "11")
        # OR if stored as strings:
        # expect(market_identifiers).to contain_exactly("10", "11")
      end

      it "stores specifier for special bets" do
        worker.perform

        # Find by integer if that's how it's stored
        market = PreMarket.find_by(market_identifier: 11)
        expect(market).not_to be_nil
        # expect(market.specifier).to eq("2.5")

        odds = market.odds
        expect(odds["Over"]).to be_present
        expect(odds["Over"]["odd"]).to eq(1.85)
        expect(odds["Over"]["outcome_id"]).to eq(2)
        expect(odds["Over"]["specifier"]).to eq("2.5")
      end
    end

    context "when fixture save fails" do
      before do
        allow_any_instance_of(Fixture).to receive(:save).and_return(false)
        allow_any_instance_of(Fixture).to receive(:errors).and_return(
          double(full_messages: ["Validation error"])
        )
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).with(/Failed to save fixture/).at_least(:once)

        expect { worker.perform }.not_to raise_error
      end

      it "does not create pre-markets for failed fixtures" do
        expect { worker.perform }.not_to change(PreMarket, :count)
      end
    end

    context "when pre-market save fails" do
      before do
        allow_any_instance_of(PreMarket).to receive(:save).and_return(false)
        allow_any_instance_of(PreMarket).to receive(:errors).and_return(
          double(full_messages: ["Market validation error"])
        )
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).with(
          /Failed to save pre-market/
        )

        expect { worker.perform }.not_to raise_error
      end
    end

    context "with multiple sports" do
      before do
        stub_const("PreMatch::PullFixturesJob::ACCEPTED_SPORTS", [1, 2])
      end

      it "fetches fixtures for all sports" do
        worker.perform

        # Check that get_matches was called multiple times (10 days * 2 sports = 20 calls)
        expect(bet_balancer).to have_received(:get_matches).at_least(20).times
      end
    end

    context "when API returns empty data" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetBalancer>
          </BetBalancer>
        XML

      it "does not create any fixtures" do
        expect { worker.perform }.not_to change(Fixture, :count)
      end
    end
  end

  describe "Sidekiq configuration" do
    it "is configured with high queue" do
      expect(described_class.sidekiq_options["queue"]).to eq(:high)
    end

    it "has retry set to 3" do
      expect(described_class.sidekiq_options["retry"]).to eq(3)
    end
  end

  describe "date parsing" do
    it "correctly parses fixture dates" do
      worker.perform

      fixture = Fixture.last
      expect(fixture.start_date).to be_a(ActiveSupport::TimeWithZone)
    end
  end
end
