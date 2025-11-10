require "rails_helper"

RSpec.describe SyncMarketsJob, type: :worker do
  let(:worker) { described_class.new }
  let(:bet_balancer) { instance_double(BetBalancer) }

  let!(:sport) { Fabricate(:sport, ext_sport_id: 1, name: "Football") }

  let(:xml_response) { <<~XML }
      <?xml version="1.0" encoding="UTF-8"?>
      <BetbalancerBetData>
        <Sports>
          <Sport BetbalancerSportID="1">
            <Texts>
              <Text Language="en">
                <Value>Football</Value>
              </Text>
            </Texts>
            <Category BetbalancerCategoryID="10" IsoName="CZE">
              <Texts>
                <Text Language="en">
                  <Value>Czech Republic</Value>
                </Text>
              </Texts>
              <Tournament BetbalancerTournamentID="100">
                <Texts>
                  <Text Language="en">
                    <Value>First League</Value>
                  </Text>
                </Texts>
                <Match BetbalancerMatchID="109379">
                  <MatchOdds>
                    <Bet OddsType="10">
                      <Texts>
                        <Text Language="en">
                          <Value>1X2</Value>
                        </Text>
                      </Texts>
                      <Odds OutCome="1" OutcomeID="1">2.15</Odds>
                      <Odds OutCome="X" OutcomeID="2">3.20</Odds>
                      <Odds OutCome="2" OutcomeID="3">3.50</Odds>
                    </Bet>
                    <Bet OddsType="11">
                      <Texts>
                        <Text Language="en">
                          <Value>Over/Under</Value>
                        </Text>
                      </Texts>
                      <Odds OutCome="Over" OutcomeID="4" SpecialBetValue="2.5">1.85</Odds>
                      <Odds OutCome="Under" OutcomeID="5" SpecialBetValue="2.5">1.95</Odds>
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
    allow(BetBalancer).to receive(:new).and_return(bet_balancer)
    allow(bet_balancer).to receive(:get_markets).and_return(
      Nokogiri.XML(xml_response)
    )
  end

  describe "#perform" do
    context "when markets don't exist" do
      it "creates new markets from API data" do
        expect { worker.perform }.to change(Market, :count).by(2)
      end

      it "creates markets with correct attributes" do
        worker.perform

        market_1x2 = Market.find_by(ext_market_id: 10, sport_id: sport.id)
        market_ou = Market.find_by(ext_market_id: 11, sport_id: sport.id)

        expect(market_1x2).to have_attributes(
          ext_market_id: 10,
          name: "1X2",
          sport_id: sport.id
        )

        expect(market_ou).to have_attributes(
          ext_market_id: 11,
          name: "Over/Under",
          sport_id: sport.id
        )
      end

      it "calls BetBalancer API for each sport" do
        worker.perform

        expect(bet_balancer).to have_received(:get_markets).with(sport_id: 1)
      end
    end

    context "when market already exists" do
      let!(:existing_market) do
        Fabricate(:market, ext_market_id: 10, name: "1X2", sport_id: sport.id)
      end

      it "does not create duplicate markets" do
        expect { worker.perform }.to change(Market, :count).by(1) # Only creates Over/Under
      end

      it "does not update market if name is unchanged" do
        original_updated_at = existing_market.updated_at

        worker.perform

        existing_market.reload
        expect(existing_market.updated_at).to eq(original_updated_at)
      end
    end

    context "when market exists but name has changed" do
      let!(:existing_market) do
        Fabricate(
          :market,
          ext_market_id: 10,
          name: "Old 1X2",
          sport_id: sport.id
        )
      end

      it "updates the market name" do
        worker.perform

        existing_market.reload
        expect(existing_market.name).to eq("1X2")
      end

      it "does not create a new market" do
        expect { worker.perform }.to change(Market, :count).by(1) # Only Over/Under is new
      end

      # it "updates the timestamp" do
      #   original_updated_at = existing_market.updated_at

      #   Timecop.travel(1.minute.from_now) { worker.perform }

      #   existing_market.reload
      #   expect(existing_market.updated_at).to be > original_updated_at
      # end
    end

    context "with multiple sports" do
      let!(:basketball_sport) do
        Fabricate(:sport, ext_sport_id: 2, name: "Basketball")
      end

      let(:basketball_xml) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="2">
                <Texts>
                  <Text Language="en">
                    <Value>Basketball</Value>
                  </Text>
                </Texts>
                <Category BetbalancerCategoryID="20" IsoName="USA">
                  <Texts>
                    <Text Language="en">
                      <Value>USA</Value>
                    </Text>
                  </Texts>
                  <Tournament BetbalancerTournamentID="200">
                    <Texts>
                      <Text Language="en">
                        <Value>NBA</Value>
                      </Text>
                    </Texts>
                    <Match BetbalancerMatchID="209379">
                      <MatchOdds>
                        <Bet OddsType="20">
                          <Texts>
                            <Text Language="en">
                              <Value>Money Line</Value>
                            </Text>
                          </Texts>
                          <Odds OutCome="1" OutcomeID="1">1.85</Odds>
                          <Odds OutCome="2" OutcomeID="2">1.95</Odds>
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
        allow(bet_balancer).to receive(:get_markets).with(
          sport_id: 1
        ).and_return(Nokogiri.XML(xml_response))

        allow(bet_balancer).to receive(:get_markets).with(
          sport_id: 2
        ).and_return(Nokogiri.XML(basketball_xml))
      end

      it "creates markets for all sports" do
        expect { worker.perform }.to change(Market, :count).by(3)
      end

      it "associates markets with correct sports" do
        worker.perform

        football_markets = Market.where(sport_id: sport.id)
        basketball_markets = Market.where(sport_id: basketball_sport.id)

        expect(football_markets.count).to eq(2)
        expect(basketball_markets.count).to eq(1)
        expect(basketball_markets.first.name).to eq("Money Line")
      end

      it "calls API for each sport" do
        worker.perform

        expect(bet_balancer).to have_received(:get_markets).with(sport_id: 1)
        expect(bet_balancer).to have_received(:get_markets).with(sport_id: 2)
      end
    end

    context "when API returns empty data" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en">
                    <Value>Football</Value>
                  </Text>
                </Texts>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "does not create any markets" do
        expect { worker.perform }.not_to change(Market, :count)
      end
    end

    context "when market creation fails" do
      before do
        # Create a failed market with real errors
        failed_market = Market.new
        failed_market.errors.add(:base, "Validation error")

        allow(failed_market).to receive(:persisted?).and_return(false)
        allow(Market).to receive(:create).and_return(failed_market)
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect { worker.perform }.not_to raise_error
      end
    end

    context "when market update fails" do
      let!(:existing_market) do
        Fabricate(
          :market,
          ext_market_id: 10,
          name: "Old Name",
          sport_id: sport.id
        )
      end

      before do
        # Create a market with real errors
        market_with_errors = Market.new
        market_with_errors.errors.add(:base, "Update validation error")

        allow_any_instance_of(Market).to receive(:update).and_return(false)
        allow_any_instance_of(Market).to receive(:errors).and_return(
          market_with_errors.errors
        )
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect { worker.perform }.not_to raise_error
      end
    end

    context "when no sports exist" do
      before { Sport.destroy_all }

      it "does not call the API" do
        worker.perform

        expect(bet_balancer).not_to have_received(:get_markets)
      end

      it "does not create any markets" do
        expect { worker.perform }.not_to change(Market, :count)
      end
    end

    context "with markets containing special characters" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en">
                    <Value>Football</Value>
                  </Text>
                </Texts>
                <Category BetbalancerCategoryID="10" IsoName="CZE">
                  <Texts>
                    <Text Language="en">
                      <Value>Czech Republic</Value>
                    </Text>
                  </Texts>
                  <Tournament BetbalancerTournamentID="100">
                    <Texts>
                      <Text Language="en">
                        <Value>First League</Value>
                      </Text>
                    </Texts>
                    <Match BetbalancerMatchID="109379">
                      <MatchOdds>
                        <Bet OddsType="10">
                          <Texts>
                            <Text Language="en">
                              <Value>Goals &amp; Cards</Value>
                            </Text>
                          </Texts>
                        </Bet>
                      </MatchOdds>
                    </Match>
                  </Tournament>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "creates market with special characters correctly" do
        worker.perform

        market = Market.find_by(ext_market_id: 10, sport_id: sport.id)
        expect(market.name).to eq("Goals & Cards")
      end
    end

    context "when same market ID exists for different sports" do
      let!(:basketball_sport) do
        Fabricate(:sport, ext_sport_id: 2, name: "Basketball")
      end

      let!(:existing_football_market) do
        Fabricate(
          :market,
          ext_market_id: 10,
          name: "Football 1X2",
          sport_id: sport.id
        )
      end

      let(:basketball_xml) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="2">
                <Texts>
                  <Text Language="en">
                    <Value>Basketball</Value>
                  </Text>
                </Texts>
                <Category BetbalancerCategoryID="20" IsoName="USA">
                  <Texts>
                    <Text Language="en">
                      <Value>USA</Value>
                    </Text>
                  </Texts>
                  <Tournament BetbalancerTournamentID="200">
                    <Texts>
                      <Text Language="en">
                        <Value>NBA</Value>
                      </Text>
                    </Texts>
                    <Match BetbalancerMatchID="209379">
                      <MatchOdds>
                        <Bet OddsType="10">
                          <Texts>
                            <Text Language="en">
                              <Value>Basketball 1X2</Value>
                            </Text>
                          </Texts>
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
        allow(bet_balancer).to receive(:get_markets).with(
          sport_id: 1
        ).and_return(Nokogiri.XML(xml_response))

        allow(bet_balancer).to receive(:get_markets).with(
          sport_id: 2
        ).and_return(Nokogiri.XML(basketball_xml))
      end

      it "creates separate markets for different sports" do
        # Already exists: 1 football market (ext_market_id: 10)
        # Will be created: 1 football market (ext_market_id: 11 - Over/Under)
        #                  1 basketball market (ext_market_id: 10)
        # Total new: 2 markets
        expect { worker.perform }.to change(Market, :count).by(2)
      end

      it "keeps markets separated by sport" do
        worker.perform

        football_markets = Market.where(sport_id: sport.id, ext_market_id: 10)
        basketball_markets =
          Market.where(sport_id: basketball_sport.id, ext_market_id: 10)

        expect(football_markets.count).to eq(1)
        expect(basketball_markets.count).to eq(1)
        expect(football_markets.first.name).to eq("1X2")
        expect(basketball_markets.first.name).to eq("Basketball 1X2")
      end
    end

    context "when API returns markets without names" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en">
                    <Value>Football</Value>
                  </Text>
                </Texts>
                <Category BetbalancerCategoryID="10" IsoName="CZE">
                  <Texts>
                    <Text Language="en">
                      <Value>Czech Republic</Value>
                    </Text>
                  </Texts>
                  <Tournament BetbalancerTournamentID="100">
                    <Texts>
                      <Text Language="en">
                        <Value>First League</Value>
                      </Text>
                    </Texts>
                    <Match BetbalancerMatchID="109379">
                      <MatchOdds>
                        <Bet OddsType="10">
                          <Texts>
                          </Texts>
                        </Bet>
                        <Bet OddsType="11">
                          <Texts>
                            <Text Language="en">
                              <Value>Over/Under</Value>
                            </Text>
                          </Texts>
                        </Bet>
                      </MatchOdds>
                    </Match>
                  </Tournament>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      # it "skips markets without names" do
      #   expect { worker.perform }.to change(Market, :count).by(1) # Only Over/Under

      #   expect(Market.find_by(ext_market_id: 10, sport_id: sport.id)).to be_nil
      #   expect(
      #     Market.find_by(ext_market_id: 11, sport_id: sport.id)
      #   ).to be_present
      # end
    end
  end

  describe "Sidekiq configuration" do
    it "is configured with default queue" do
      expect(described_class.sidekiq_options["queue"]).to eq(:default)
    end

    it "has retry set to 1" do
      expect(described_class.sidekiq_options["retry"]).to eq(1)
    end
  end
end
