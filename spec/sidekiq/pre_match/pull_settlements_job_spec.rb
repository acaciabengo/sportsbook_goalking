require "rails_helper"

RSpec.describe PreMatch::PullSettlementsJob, type: :worker do
  let(:worker) { described_class.new }
  let(:bet_balancer) { instance_double(BetBalancer) }

  let(:xml_response) { <<~XML }
    <?xml version="1.0" encoding="UTF-8"?>
    <BetbalancerBetData>
      <Sports>
        <Sport BetbalancerSportID="1">
          <Category BetbalancerCategoryID="10" IsoName="CZE">
            <Tournament BetbalancerTournamentID="100">
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
                    <MatchDate>2004-08-23T16:40:00</MatchDate>
                  </DateInfo>
                  <StatusInfo>
                    <Off>0</Off>
                  </StatusInfo>
                </Fixture>
                <MatchOdds>
                  <Bet OddsType="10">
                    <Odds OutCome="1" OutComeId="1">2.15</Odds>
                    <Odds OutCome="X" OutComeId="2">2.85</Odds>
                    <Odds OutCome="2" OutComeId="3">2.9</Odds>
                  </Bet>
                </MatchOdds>
                <Result>
                  <ScoreInfo>
                    <Score Type="FT">1:0</Score>
                    <Score Type="HT">0:0</Score>
                  </ScoreInfo>
                </Result>
                <BetResult>
                  <W OddsType="10" OutComeId="1" OutCome="1" VoidFactor="0.0"/>
                  <L OddsType="10" OutComeId="2" OutCome="X" VoidFactor="0.0"/>
                  <L OddsType="10" OutComeId="3" OutCome="2" VoidFactor="0.0"/>
                </BetResult>
              </Match>
            </Tournament>
          </Category>
        </Sport>
      </Sports>
    </BetbalancerBetData>
  XML

  let!(:fixture) do
    Fabricate(:fixture, event_id: "109379", match_status: "not_started", start_date: 12.hours.ago)
  end

  let!(:pre_market) do
    Fabricate(
      :pre_market,
      fixture: fixture,
      market_identifier: "10",
      specifier: nil,
      status: "active",
      results: {}
    )
  end

  before do
    allow(SendSms).to receive(:process_sms_now).and_return(true)
    allow(BetBalancer).to receive(:new).and_return(bet_balancer)
    allow(bet_balancer).to receive(:get_matches).and_return([200, Nokogiri.XML(xml_response)])
    allow(CloseSettledBetsJob).to receive(:perform_async)
  end

  describe "#perform" do
    context "when processing a fixture with settlement data" do
      it "fetches settlement data from BetBalancer" do
        expect(bet_balancer).to receive(:get_matches).with(
          match_id: "109379",
          want_score: true
        )

        worker.perform(fixture.id)
      end

      it "parses bet results from XML" do
        worker.perform(fixture.id)

        pre_market.reload
        results = pre_market.results

        expect(results["1"]).to be_present
        expect(results["1"]["status"]).to eq("W")
        expect(results["1"]["outcome_id"]).to eq(1)
        expect(results["1"]["void_factor"]).to eq(0.0)
      end

      it "updates pre-market with all outcomes" do
        worker.perform(fixture.id)

        pre_market.reload
        results = pre_market.results

        expect(results.keys).to contain_exactly("1", "X", "2")
        expect(results["1"]["status"]).to eq("W")
        expect(results["X"]["status"]).to eq("L")
        expect(results["2"]["status"]).to eq("L")
      end

      it "marks pre-market as settled" do
        worker.perform(fixture.id)

        pre_market.reload
        expect(pre_market.status).to eq("settled")
      end

      it "enqueues CloseSettledBetsJob" do
        expect(CloseSettledBetsJob).to receive(:perform_async).with(fixture.id, pre_market.id, 'PreMatch')
        worker.perform(fixture.id)
      end

      it "updates fixture score from Result node" do
        worker.perform(fixture.id)

        fixture.reload
        expect(fixture.home_score).to eq("1")
        expect(fixture.away_score).to eq("0")
      end
    end

    context "when fixture is not found" do
      it "logs error and returns early" do
        expect(Rails.logger).to receive(:error).with(/Fixture not found/)
        worker.perform(999999)
      end

      it "does not call BetBalancer" do
        expect(bet_balancer).not_to receive(:get_matches)
        worker.perform(999999)
      end
    end

    context "when pre-market already has results" do
      before do
        pre_market.update(
          results: { "X" => { "status" => "W", "outcome_id" => 2, "void_factor" => 0.0 } }
        )
      end

      it "replaces existing results with new results" do
        worker.perform(fixture.id)

        pre_market.reload
        results = pre_market.results

        expect(results["X"]["status"]).to eq("L")
        expect(results["1"]).to be_present
        expect(results["2"]).to be_present
      end
    end

    context "when BetBalancer returns non-200 status" do
      before do
        allow(bet_balancer).to receive(:get_matches).and_return([500, nil])
      end

      it "does not update pre-market" do
        expect { worker.perform(fixture.id) }.not_to change { pre_market.reload.results }
      end

      it "does not mark pre-market as settled" do
        worker.perform(fixture.id)

        pre_market.reload
        expect(pre_market.status).to eq("active")
      end

      it "does not enqueue CloseSettledBetsJob" do
        expect(CloseSettledBetsJob).not_to receive(:perform_async)
        worker.perform(fixture.id)
      end
    end

    context "when settlement data is nil" do
      before do
        allow(bet_balancer).to receive(:get_matches).and_return([200, nil])
      end

      it "does not update pre-market" do
        expect { worker.perform(fixture.id) }.not_to change { pre_market.reload.results }
      end

      it "does not enqueue CloseSettledBetsJob" do
        expect(CloseSettledBetsJob).not_to receive(:perform_async)
        worker.perform(fixture.id)
      end
    end

    context "when pre-market is already settled" do
      before { pre_market.update(status: "settled") }

      it "re-settles with new results" do
        worker.perform(fixture.id)

        pre_market.reload
        expect(pre_market.results["1"]["status"]).to eq("W")
      end

      it "enqueues CloseSettledBetsJob for re-settlement" do
        expect(CloseSettledBetsJob).to receive(:perform_async).with(fixture.id, pre_market.id, 'PreMatch')
        worker.perform(fixture.id)
      end
    end

    context "when bet results contain specifiers" do
      let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <BetbalancerBetData>
          <Sports>
            <Sport BetbalancerSportID="1">
              <Category BetbalancerCategoryID="10" IsoName="CZE">
                <Tournament BetbalancerTournamentID="100">
                  <Match BetbalancerMatchID="109379">
                    <Result>
                      <ScoreInfo>
                        <Score Type="FT">3:1</Score>
                      </ScoreInfo>
                    </Result>
                    <BetResult>
                      <W OddsType="18" OutComeId="4" OutCome="Over" VoidFactor="0.0" SpecialBetValue="2.5"/>
                      <L OddsType="18" OutComeId="5" OutCome="Under" VoidFactor="0.0" SpecialBetValue="2.5"/>
                    </BetResult>
                  </Match>
                </Tournament>
              </Category>
            </Sport>
          </Sports>
        </BetbalancerBetData>
      XML

      let!(:over_under_market) do
        Fabricate(
          :pre_market,
          fixture: fixture,
          market_identifier: "18",
          specifier: "2.5",
          status: "active",
          results: {}
        )
      end

      it "processes market with correct specifier" do
        worker.perform(fixture.id)

        over_under_market.reload
        results = over_under_market.results

        expect(results["Over"]["status"]).to eq("W")
        expect(results["Under"]["status"]).to eq("L")
        expect(results["Over"]["void_factor"]).to eq(0.0)
      end
    end

    context "when bet results are cancelled (void_factor = 1.0)" do
      let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <BetbalancerBetData>
          <Sports>
            <Sport BetbalancerSportID="1">
              <Category BetbalancerCategoryID="10" IsoName="CZE">
                <Tournament BetbalancerTournamentID="100">
                  <Match BetbalancerMatchID="109379">
                    <Result>
                      <ScoreInfo>
                        <Score Type="FT">0:0</Score>
                      </ScoreInfo>
                    </Result>
                    <BetResult>
                      <C OddsType="10" OutComeId="1" OutCome="1" VoidFactor="1.0"/>
                      <C OddsType="10" OutComeId="2" OutCome="X" VoidFactor="1.0"/>
                      <C OddsType="10" OutComeId="3" OutCome="2" VoidFactor="1.0"/>
                    </BetResult>
                  </Match>
                </Tournament>
              </Category>
            </Sport>
          </Sports>
        </BetbalancerBetData>
      XML

      it "marks results with cancelled status" do
        worker.perform(fixture.id)

        pre_market.reload
        results = pre_market.results

        expect(results["1"]["status"]).to eq("C")
        expect(results["1"]["void_factor"]).to eq(1.0)
        expect(results["X"]["status"]).to eq("C")
        expect(results["2"]["status"]).to eq("C")
      end
    end

    context "when bet results are refunded" do
      let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <BetbalancerBetData>
          <Sports>
            <Sport BetbalancerSportID="1">
              <Category BetbalancerCategoryID="10" IsoName="CZE">
                <Tournament BetbalancerTournamentID="100">
                  <Match BetbalancerMatchID="109379">
                    <Result>
                      <ScoreInfo>
                        <Score Type="FT">1:0</Score>
                      </ScoreInfo>
                    </Result>
                    <BetResult>
                      <R OddsType="10" OutComeId="1" OutCome="1" VoidFactor="1.0"/>
                      <R OddsType="10" OutComeId="2" OutCome="X" VoidFactor="1.0"/>
                      <R OddsType="10" OutComeId="3" OutCome="2" VoidFactor="1.0"/>
                    </BetResult>
                  </Match>
                </Tournament>
              </Category>
            </Sport>
          </Sports>
        </BetbalancerBetData>
      XML

      it "marks results with refund status" do
        worker.perform(fixture.id)

        pre_market.reload
        results = pre_market.results

        expect(results["1"]["status"]).to eq("R")
        expect(results["X"]["status"]).to eq("R")
        expect(results["2"]["status"]).to eq("R")
      end
    end

    context "when no bet results exist in XML" do
      let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <BetbalancerBetData>
          <Sports>
            <Sport BetbalancerSportID="1">
              <Category BetbalancerCategoryID="10" IsoName="CZE">
                <Tournament BetbalancerTournamentID="100">
                  <Match BetbalancerMatchID="109379">
                    <MatchOdds>
                      <Bet OddsType="10">
                        <Odds OutCome="1" OutComeId="1">2.20</Odds>
                        <Odds OutCome="X" OutComeId="2">2.90</Odds>
                        <Odds OutCome="2" OutComeId="3">2.95</Odds>
                      </Bet>
                    </MatchOdds>
                  </Match>
                </Tournament>
              </Category>
            </Sport>
          </Sports>
        </BetbalancerBetData>
      XML

      it "updates odds but does not settle" do
        worker.perform(fixture.id)

        pre_market.reload
        expect(pre_market.status).to eq("active")
        expect(pre_market.odds["1"]["odd"]).to eq(2.20)
      end

      it "does not enqueue CloseSettledBetsJob" do
        expect(CloseSettledBetsJob).not_to receive(:perform_async)
        worker.perform(fixture.id)
      end
    end

    context "when odds update for existing market" do
      let(:xml_response) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <BetbalancerBetData>
          <Sports>
            <Sport BetbalancerSportID="1">
              <Category BetbalancerCategoryID="10">
                <Tournament BetbalancerTournamentID="100">
                  <Match BetbalancerMatchID="109379">
                    <MatchOdds>
                      <Bet OddsType="10">
                        <Odds OutCome="1" OutComeId="1">3.50</Odds>
                        <Odds OutCome="X" OutComeId="2">3.20</Odds>
                        <Odds OutCome="2" OutComeId="3">2.10</Odds>
                      </Bet>
                    </MatchOdds>
                  </Match>
                </Tournament>
              </Category>
            </Sport>
          </Sports>
        </BetbalancerBetData>
      XML

      before do
        pre_market.update(odds: { "1" => { "odd" => 2.0 }, "X" => { "odd" => 3.0 }, "2" => { "odd" => 4.0 } })
      end

      it "updates odds on existing market" do
        worker.perform(fixture.id)

        pre_market.reload
        expect(pre_market.odds["1"]["odd"]).to eq(3.50)
        expect(pre_market.odds["X"]["odd"]).to eq(3.20)
        expect(pre_market.odds["2"]["odd"]).to eq(2.10)
      end
    end
  end

  describe "Sidekiq configuration" do
    it "is configured with high queue" do
      expect(described_class.sidekiq_options["queue"]).to eq(:high)
    end

    it "has retry set to 1" do
      expect(described_class.sidekiq_options["retry"]).to eq(1)
    end
  end
end
