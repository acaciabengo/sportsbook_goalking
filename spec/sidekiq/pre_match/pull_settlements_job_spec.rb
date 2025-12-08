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
                    <Comment>
                      <Texts>
                        <Text>
                          <Value>1:0(62.)Luis Fabiano</Value>
                        </Text>
                      </Texts>
                    </Comment>
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
    Fabricate(:fixture, event_id: "109379", match_status: "finished", start_date: 12.hours.ago)
  end

  let!(:pre_market) do
    Fabricate(
      :pre_market,
      fixture: fixture,
      market_identifier: 10,
      specifier: nil,
      status: "active",
      results: {}
    )
  end

  before do
    # Stub SendSms to prevent SMS sending during tests
    allow(SendSms).to receive(:process_sms_now).and_return(true)

    # Stub BetBalancer
    allow(BetBalancer).to receive(:new).and_return(bet_balancer)
    allow(bet_balancer).to receive(:get_matches).and_return(
      [200, Nokogiri.XML(xml_response)]
    )

    # Stub Sidekiq bulk push
    allow(Sidekiq::Client).to receive(:push_bulk)
  end

  describe "#perform" do
    context "when processing active markets with finished fixtures" do
      it "fetches settlement data from BetBalancer" do
        expect(bet_balancer).to receive(:get_matches).with(
          match_id: "109379",
          want_score: true
        )

        worker.perform
      end

      it "parses bet results from XML" do
        worker.perform

        pre_market.reload
        results = pre_market.results

        expect(results["1"]).to be_present
        expect(results["1"]["status"]).to eq("W")
        expect(results["1"]["outcome_id"]).to eq("1")
        expect(results["1"]["void_factor"]).to eq(0.0)
      end

      it "updates pre-market with all outcomes" do
        worker.perform

        pre_market.reload
        results = pre_market.results

        expect(results.keys).to contain_exactly("1", "X", "2")
        expect(results["1"]["status"]).to eq("W")
        expect(results["X"]["status"]).to eq("L")
        expect(results["2"]["status"]).to eq("L")
      end

      it "marks pre-market as settled" do
        worker.perform

        pre_market.reload
        expect(pre_market.status).to eq("settled")
      end

      it "enqueues CloseSettledBetsJob via bulk push" do
        expect(Sidekiq::Client).to receive(:push_bulk) do |jobs|
          expect(jobs.length).to eq(1)
          expect(jobs[0]['class']).to eq('CloseSettledBetsJob')
          expect(jobs[0]['args']).to eq([fixture.id, pre_market.id, 'PreMatch'])
        end
        
        worker.perform
      end
    end

    context "when pre-market already has results" do
      before do
        pre_market.update(
          results: { "X" => { "status" => "W", "outcome_id" => "2", "void_factor" => 0.0 } }
        )
      end

      it "replaces existing results with new results" do
        worker.perform

        pre_market.reload
        results = pre_market.results

        # New results should override existing
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
        expect { worker.perform }.not_to change { pre_market.reload.results }
      end

      it "does not mark pre-market as settled" do
        worker.perform

        pre_market.reload
        expect(pre_market.status).to eq("active")
      end

      it "does not enqueue CloseSettledBetsJob" do
        expect(Sidekiq::Client).not_to receive(:push_bulk)
        worker.perform
      end
    end

    context "when settlement data is nil" do
      before do
        allow(bet_balancer).to receive(:get_matches).and_return([200, nil])
      end

      it "does not update pre-market" do
        expect { worker.perform }.not_to change { pre_market.reload.results }
      end

      it "does not enqueue CloseSettledBetsJob" do
        expect(Sidekiq::Client).not_to receive(:push_bulk)
        worker.perform
      end
    end

    context "when fixture is not finished" do
      before { fixture.update(match_status: "not_started") }

      it "does not process the market" do
        expect(bet_balancer).not_to receive(:get_matches)
        worker.perform
      end
    end

    context "when fixture is outside 24 hour window" do
      before { fixture.update(start_date: 25.hours.ago) }

      it "does not process the market" do
        expect(bet_balancer).not_to receive(:get_matches)
        worker.perform
      end
    end

    context "when pre-market is already settled" do
      before { pre_market.update(status: "settled") }

      it "does not process the market again" do
        worker.perform
        
        # Market should remain settled with same results
        pre_market.reload
        expect(pre_market.status).to eq("settled")
      end

      it "does not enqueue CloseSettledBetsJob" do
        expect(Sidekiq::Client).not_to receive(:push_bulk)
        worker.perform
      end
    end

    context "when processing multiple markets in batches" do
      let!(:fixture2) do
        Fabricate(:fixture, event_id: "109380", match_status: "finished", start_date: 12.hours.ago)
      end

      let!(:pre_market2) do
        Fabricate(
          :pre_market,
          fixture: fixture2,
          market_identifier: 10,
          specifier: nil,
          status: "active",
          results: {}
        )
      end

      let(:xml_response2) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Category BetbalancerCategoryID="10" IsoName="CZE">
                  <Tournament BetbalancerTournamentID="100">
                    <Match BetbalancerMatchID="109380">
                      <Result>
                        <ScoreInfo>
                          <Score Type="FT">2:2</Score>
                        </ScoreInfo>
                      </Result>
                      <BetResult>
                        <L OddsType="10" OutComeId="1" OutCome="1" VoidFactor="0.0"/>
                        <W OddsType="10" OutComeId="2" OutCome="X" VoidFactor="0.0"/>
                        <L OddsType="10" OutComeId="3" OutCome="2" VoidFactor="0.0"/>
                      </BetResult>
                    </Match>
                  </Tournament>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      before do
        allow(bet_balancer).to receive(:get_matches).with(
          match_id: "109379",
          want_score: true
        ).and_return([200, Nokogiri.XML(xml_response)])

        allow(bet_balancer).to receive(:get_matches).with(
          match_id: "109380",
          want_score: true
        ).and_return([200, Nokogiri.XML(xml_response2)])
      end

      it "processes all markets" do
        worker.perform

        pre_market.reload
        pre_market2.reload

        expect(pre_market.status).to eq("settled")
        expect(pre_market2.status).to eq("settled")
      end

      it "enqueues jobs for both markets via bulk push" do
        # Each fixture gets its own bulk push call
        expect(Sidekiq::Client).to receive(:push_bulk).twice do |jobs|
          expect(jobs.length).to eq(1)
        end
        worker.perform
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
          market_identifier: 18,
          specifier: "2.5",
          status: "active",
          results: {}
        )
      end

      it "processes market with correct specifier" do
        worker.perform

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
        worker.perform

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
        worker.perform

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
                      <Result>
                        <ScoreInfo>
                          <Score Type="FT">1:0</Score>
                        </ScoreInfo>
                      </Result>
                    </Match>
                  </Tournament>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "does not update pre-market results" do
        initial_results = pre_market.results
        worker.perform

        pre_market.reload
        expect(pre_market.results).to eq(initial_results)
      end

      it "does not mark pre-market as settled" do
        worker.perform

        pre_market.reload
        expect(pre_market.status).to eq("active")
      end

      it "does not enqueue CloseSettledBetsJob" do
        expect(Sidekiq::Client).not_to receive(:push_bulk)
        worker.perform
      end
    end

    context "when processing in batches of 50" do
      let!(:markets) do
        55.times.map do |i|
          fixture =
            Fabricate(
              :fixture,
              event_id: (200_000 + i).to_s,
              match_status: "finished",
              start_date: 12.hours.ago
            )
          Fabricate(
            :pre_market,
            fixture: fixture,
            market_identifier: 1,
            specifier: nil,
            status: "active",
            results: {}
          )
        end
      end

      it "processes markets individually" do
        # Stub all BetBalancer calls
        allow(bet_balancer).to receive(:get_matches).and_return(
          [200, Nokogiri.XML(xml_response)]
        )

        # Should process all 56 fixtures (1 from let! + 55 from this context)
        expect(bet_balancer).to receive(:get_matches).at_least(55).times

        worker.perform
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
