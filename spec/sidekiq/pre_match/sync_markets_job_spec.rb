require "rails_helper"

RSpec.describe PreMatch::SyncMarketsJob, type: :worker do
  let(:worker) { described_class.new }
  let(:bet_balancer) { instance_double(BetBalancer) }

  let(:xml_response) { <<~XML }
    <?xml version="1.0" encoding="UTF-8"?>
    <BetbalancerBetData>
      <Sports>
        <Sport BetbalancerSportID="1">
          <Category BetbalancerCategoryID="10">
            <Tournament BetbalancerTournamentID="100">
              <Match BetbalancerMatchID="109379">
                <Fixture>
                  <DateInfo>
                    <MatchDate>2026-01-28T16:40:00</MatchDate>
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
              </Match>
            </Tournament>
          </Category>
        </Sport>
      </Sports>
    </BetbalancerBetData>
  XML

  let!(:fixture) do
    Fabricate(:fixture, event_id: 109379, match_status: "not_started")
  end

  before do
    allow(BetBalancer).to receive(:new).and_return(bet_balancer)
    allow(bet_balancer).to receive(:get_updates).and_return([200, Nokogiri.XML(xml_response)])
  end

  describe "#perform" do
    context "when fetching updates successfully" do
      it "fetches updates from BetBalancer" do
        expect(bet_balancer).to receive(:get_updates)
        worker.perform
      end

      it "creates new PreMarket records" do
        expect { worker.perform }.to change { PreMarket.count }.by(1)
      end

      it "stores odds correctly" do
        worker.perform

        market = PreMarket.find_by(fixture_id: fixture.id, market_identifier: "10")
        expect(market.odds["1"]["odd"]).to eq(2.15)
        expect(market.odds["X"]["odd"]).to eq(2.85)
        expect(market.odds["2"]["odd"]).to eq(2.9)
      end
    end

    context "when updating existing markets" do
      let!(:pre_market) do
        Fabricate(
          :pre_market,
          fixture: fixture,
          market_identifier: "10",
          specifier: nil,
          status: "active",
          odds: { "1" => { "odd" => 1.5 } }
        )
      end

      it "updates odds on existing market" do
        worker.perform

        pre_market.reload
        expect(pre_market.odds["1"]["odd"]).to eq(2.15)
        expect(pre_market.odds["X"]["odd"]).to eq(2.85)
      end
    end

    context "when BetResult exists in response" do
      let(:xml_with_settlement) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <BetbalancerBetData>
          <Sports>
            <Sport BetbalancerSportID="1">
              <Category BetbalancerCategoryID="10">
                <Tournament BetbalancerTournamentID="100">
                  <Match BetbalancerMatchID="109379">
                    <Fixture>
                      <StatusInfo>
                        <Off>1</Off>
                      </StatusInfo>
                    </Fixture>
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

      let!(:pre_market) do
        Fabricate(
          :pre_market,
          fixture: fixture,
          market_identifier: "10",
          specifier: nil,
          status: "active",
          odds: { "1" => { "odd" => 2.15 } }
        )
      end

      before do
        allow(bet_balancer).to receive(:get_updates).and_return([200, Nokogiri.XML(xml_with_settlement)])
        allow(CloseSettledBetsJob).to receive(:perform_async)
      end

      it "settles the market" do
        worker.perform

        pre_market.reload
        expect(pre_market.status).to eq("settled")
      end

      it "stores settlement results" do
        worker.perform

        pre_market.reload
        expect(pre_market.results["1"]["status"]).to eq("W")
        expect(pre_market.results["X"]["status"]).to eq("L")
        expect(pre_market.results["2"]["status"]).to eq("L")
      end

      it "enqueues CloseSettledBetsJob" do
        expect(CloseSettledBetsJob).to receive(:perform_async).with(fixture.id, pre_market.id, 'PreMatch')
        worker.perform
      end
    end

    context "when fixture date changes" do
      let(:xml_with_date_change) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <BetbalancerBetData>
          <Sports>
            <Sport BetbalancerSportID="1">
              <Category BetbalancerCategoryID="10">
                <Tournament BetbalancerTournamentID="100">
                  <Match BetbalancerMatchID="109379">
                    <Fixture>
                      <DateInfo>
                        <MatchDate>2026-02-01T18:00:00</MatchDate>
                      </DateInfo>
                      <StatusInfo>
                        <Off>0</Off>
                      </StatusInfo>
                    </Fixture>
                  </Match>
                </Tournament>
              </Category>
            </Sport>
          </Sports>
        </BetbalancerBetData>
      XML

      before do
        allow(bet_balancer).to receive(:get_updates).and_return([200, Nokogiri.XML(xml_with_date_change)])
      end

      it "updates fixture start_date" do
        worker.perform

        fixture.reload
        expect(fixture.start_date.to_date).to eq(Date.new(2026, 2, 1))
      end
    end

    context "when BetBalancer returns error" do
      before do
        allow(bet_balancer).to receive(:get_updates).and_return([500, nil])
      end

      it "does not raise error" do
        expect { worker.perform }.not_to raise_error
      end

      it "does not create markets" do
        expect { worker.perform }.not_to change { PreMarket.count }
      end
    end

    context "when fixture not found in database" do
      before do
        fixture.destroy
      end

      it "skips the match" do
        expect { worker.perform }.not_to raise_error
      end
    end

    context "with specifier-based markets" do
      let(:xml_with_specifiers) { <<~XML }
        <?xml version="1.0" encoding="UTF-8"?>
        <BetbalancerBetData>
          <Sports>
            <Sport BetbalancerSportID="1">
              <Category BetbalancerCategoryID="10">
                <Tournament BetbalancerTournamentID="100">
                  <Match BetbalancerMatchID="109379">
                    <Fixture>
                      <StatusInfo>
                        <Off>0</Off>
                      </StatusInfo>
                    </Fixture>
                    <MatchOdds>
                      <Bet OddsType="18">
                        <Odds OutCome="Over" OutComeId="12" SpecialBetValue="2.5">1.85</Odds>
                        <Odds OutCome="Under" OutComeId="13" SpecialBetValue="2.5">1.95</Odds>
                        <Odds OutCome="Over" OutComeId="12" SpecialBetValue="3.5">2.50</Odds>
                        <Odds OutCome="Under" OutComeId="13" SpecialBetValue="3.5">1.50</Odds>
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
        allow(bet_balancer).to receive(:get_updates).and_return([200, Nokogiri.XML(xml_with_specifiers)])
      end

      it "creates separate markets for each specifier" do
        expect { worker.perform }.to change { PreMarket.count }.by(2)

        market_25 = PreMarket.find_by(fixture_id: fixture.id, market_identifier: "18", specifier: "2.5")
        market_35 = PreMarket.find_by(fixture_id: fixture.id, market_identifier: "18", specifier: "3.5")

        expect(market_25).to be_present
        expect(market_35).to be_present
        expect(market_25.odds["Over"]["odd"]).to eq(1.85)
        expect(market_35.odds["Over"]["odd"]).to eq(2.50)
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
