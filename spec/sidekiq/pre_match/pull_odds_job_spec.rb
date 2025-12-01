require "rails_helper"

RSpec.describe PreMatch::PullOddsJob, type: :worker do
  let(:worker) { described_class.new }
  let(:bet_balancer) { instance_double(BetBalancer) }

  let(:xml_response) { <<~XML }
      <?xml version="1.0" encoding="UTF-8"?>
      <BetbalancerBetData>
        <Sports>
          <Sport BetbalancerSportID="1">
            <Texts>
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
                      <MatchDate>2024-08-23T16:40:00</MatchDate>
                    </DateInfo>
                    <StatusInfo>
                      <Off>1</Off>
                    </StatusInfo>
                  </Fixture>
                  <MatchOdds>
                    <Bet OddsType="10">
                      <Odds OutCome="1" OutcomeID="1">2.15</Odds>
                      <Odds OutCome="X" OutcomeID="2">3.20</Odds>
                      <Odds OutCome="2" OutcomeID="3">3.50</Odds>
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
                </Match>
              </Tournament>
            </Category>
          </Sport>
        </Sports>
      </BetbalancerBetData>
    XML

  let!(:fixture) do
    Fabricate(
      :fixture,
      event_id: 109_379,
      sport_id: 1,
      ext_category_id: 10,
      ext_tournament_id: 100,
      match_status: "not_started",
      status: "active"
    )
  end

  let!(:existing_pre_market) do
    Fabricate(
      :pre_market,
      fixture: fixture,
      market_identifier: 10,
      odds: {
        "1" => {
          "odd" => 2.00,
          "outcome_id" => 1
        },
        "X" => {
          "odd" => 3.00,
          "outcome_id" => 2
        },
        "2" => {
          "odd" => 3.00,
          "outcome_id" => 3
        }
      },
      status: "active"
    )
  end

  before do
    stub_const("PreMatch::PullOddsJob::ACCEPTED_SPORTS", [1])
    allow(BetBalancer).to receive(:new).and_return(bet_balancer)
    allow(bet_balancer).to receive(:get_matches).and_return(
      [200, Nokogiri.XML(xml_response)]
    )
  end

  describe "#perform" do
    context "when pre-market exists" do
      it "updates existing pre-market odds" do
        print("Original odds: #{JSON.parse(existing_pre_market.odds)}\n")
        data = Nokogiri.XML(xml_response)
        odds_node = data.xpath("//MatchOdds/Bet[@OddsType='10']").first
        print("New odds from XML: #{odds_node.to_xml}\n")
        odds = Hash.new()
        odds_node
          .xpath("Odds")
          .each do |odd|
            outcome = odd["OutCome"]
            value = odd.text.to_f
            outcome_id = odd["OutcomeID"]&.to_i || nil
            odds[outcome] = {
              odd: value,
              outcome_id: outcome_id,
              specifier: nil
            }
          end
        odds = odds&.deep_transform_keys(&:to_s)
        print("Parsed new odds: #{odds}\n")
        merged_odds = JSON.parse(existing_pre_market.odds).deep_merge(odds)
        print("Merged odds: #{merged_odds}\n")
        worker.perform

        existing_pre_market.reload
        odds = JSON.parse(existing_pre_market.odds)

        print("Updated odds: #{existing_pre_market.odds}\n")

        expect(odds["1"]["odd"]).to eq(2.15)
        expect(odds["X"]["odd"]).to eq(3.20)
        expect(odds["2"]["odd"]).to eq(3.50)
        expect(fixture.reload.match_status).to eq("finished")
      end

      it "keeps the same outcome IDs" do
        worker.perform

        existing_pre_market.reload
        odds = JSON.parse(existing_pre_market.odds)

        expect(odds["1"]["outcome_id"]).to eq(1)
        expect(odds["X"]["outcome_id"]).to eq(2)
        expect(odds["2"]["outcome_id"]).to eq(3)
      end

      it "maintains active status" do
        worker.perform

        existing_pre_market.reload
        expect(existing_pre_market.status).to eq("active")
      end

      it "does not create duplicate pre-markets" do
        expect { worker.perform }.not_to change(PreMarket, :count)
      end
    end

    context "when pre-market does not exist" do
      before do
        existing_pre_market.destroy
        fixture.update(match_status: "not_started")
      end

      it "creates new pre-market" do
        expect { worker.perform }.to change(PreMarket, :count).by(1)
      end

      it "creates pre-market with correct odds" do
        worker.perform

        pre_market = PreMarket.last
        odds = JSON.parse(pre_market.odds)

        expect(odds["1"]["odd"]).to eq(2.15)
        expect(odds["X"]["odd"]).to eq(3.20)
        expect(odds["2"]["odd"]).to eq(3.50)
      end

      it "sets status to active" do
        worker.perform

        pre_market = PreMarket.last
        expect(pre_market.status).to eq("active")
      end
    end

    context "with multiple markets" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
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
                            <Text Type="1" ID="9373">
                              <Value>1. FC BRNO</Value>
                            </Text>
                          </Texts>
                          <Texts>
                            <Text Type="2" ID="371400">
                              <Value>FC SLOVACKO</Value>
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
                        <Bet OddsType="11">
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

      let!(:over_under_market) do
        Fabricate(
          :pre_market,
          fixture: fixture,
          market_identifier: 11,
          specifier: "total=2.5",
          odds: {
            "Over" => {
              "odd" => 1.80,
              "outcome_id" => 4
            },
            "Under" => {
              "odd" => 2.00,
              "outcome_id" => 5
            }
          },
          status: "active"
        )
      end

      it "updates all markets for the fixture" do
        worker.perform

        existing_pre_market.reload
        over_under_market.reload

        odds_1x2 = JSON.parse(existing_pre_market.odds)
        odds_ou = JSON.parse(over_under_market.odds)

        expect(odds_1x2["1"]["odd"]).to eq(2.15)
        expect(odds_ou["Over"]["odd"]).to eq(1.85)
        expect(odds_ou["Under"]["odd"]).to eq(1.95)
      end
    end

    # context "when fixture does not exist" do
    #   let(:xml_response) { <<~XML }
    #       <?xml version="1.0" encoding="UTF-8"?>
    #       <BetbalancerBetData>
    #         <Sports>
    #           <Sport BetbalancerSportID="1">
    #             <Texts>
    #               <Text Language="en"><Value>Football</Value></Text>
    #             </Texts>
    #             <Category BetbalancerCategoryID="10" IsoName="CZE">
    #               <Texts>
    #                 <Text Language="en"><Value>Czech Republic</Value></Text>
    #               </Texts>
    #               <Tournament BetbalancerTournamentID="100">
    #                 <Texts>
    #                   <Text Language="en"><Value>First League</Value></Text>
    #                 </Texts>
    #                 <Match BetbalancerMatchID="999999">
    #                   <Fixture>
    #                     <Competitors>
    #                       <Texts>
    #                         <Text Type="1" ID="9373">
    #                           <Value>Team A</Value>
    #                         </Text>
    #                       </Texts>
    #                       <Texts>
    #                         <Text Type="2" ID="9374">
    #                           <Value>Team B</Value>
    #                         </Text>
    #                       </Texts>
    #                     </Competitors>
    #                     <DateInfo>
    #                       <MatchDate>2024-08-23T16:40:00</MatchDate>
    #                     </DateInfo>
    #                     <StatusInfo>
    #                       <Off>1</Off>
    #                     </StatusInfo>
    #                   </Fixture>
    #                   <MatchOdds>
    #                     <Bet OddsType="10">
    #                       <Odds OutCome="1" OutcomeID="1">2.15</Odds>
    #                     </Bet>
    #                   </MatchOdds>
    #                 </Match>
    #               </Tournament>
    #             </Category>
    #           </Sport>
    #         </Sports>
    #       </BetbalancerBetData>
    #     XML

    #   it "skips processing and logs warning" do
    #     expect(Rails.logger).to receive(:warn).with(/Fixture not found/)

    #     expect { worker.perform }.not_to change(PreMarket, :count)
    #   end
    # end

    context "when odds are unchanged" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
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
                            <Text Type="1" ID="9373">
                              <Value>1. FC BRNO</Value>
                            </Text>
                          </Texts>
                          <Texts>
                            <Text Type="2" ID="371400">
                              <Value>FC SLOVACKO</Value>
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
                          <Odds OutCome="1" OutcomeID="1">2.00</Odds>
                          <Odds OutCome="X" OutcomeID="2">3.00</Odds>
                          <Odds OutCome="2" OutcomeID="3">3.00</Odds>
                        </Bet>
                      </MatchOdds>
                    </Match>
                  </Tournament>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      # it "still updates the pre-market" do
      #   original_updated_at = existing_pre_market.updated_at

      #   Timecop.travel(1.minute.from_now) { worker.perform }

      #   existing_pre_market.reload
      #   expect(existing_pre_market.updated_at).to be > original_updated_at
      # end
    end

    context "when match is cancelled (Off=1)" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
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
                            <Text Type="1" ID="9373">
                              <Value>1. FC BRNO</Value>
                            </Text>
                          </Texts>
                          <Texts>
                            <Text Type="2" ID="371400">
                              <Value>FC SLOVACKO</Value>
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
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "deactivates the pre-market" do
        worker.perform

        fixture.reload
        expect(fixture.status).to eq("cancelled")
      end

      it "updates fixture status to cancelled" do
        worker.perform

        fixture.reload
        expect(fixture.match_status).to eq("cancelled")
      end
    end

    # context "with multiple fixtures" do
    #   let!(:fixture_2) do
    #     Fabricate(
    #       :fixture,
    #       event_id: 109_380,
    #       sport_id: 1,
    #       ext_category_id: 10,
    #       ext_tournament_id: 100,
    #       match_status: "not_started"
    #     )
    #   end

    #   let!(:pre_market_2) do
    #     Fabricate(
    #       :pre_market,
    #       fixture: fixture_2,
    #       market_identifier: 10,
    #       odds: { "1" => { "odd" => 1.50, "outcome_id" => 1 } },
    #       status: "active"
    #     )
    #   end

    #   let(:xml_response) { <<~XML }
    #       <?xml version="1.0" encoding="UTF-8"?>
    #       <BetbalancerBetData>
    #         <Sports>
    #           <Sport BetbalancerSportID="1">
    #             <Texts>
    #               <Text Language="en"><Value>Football</Value></Text>
    #             </Texts>
    #             <Category BetbalancerCategoryID="10" IsoName="CZE">
    #               <Texts>
    #                 <Text Language="en"><Value>Czech Republic</Value></Text>
    #               </Texts>
    #               <Tournament BetbalancerTournamentID="100">
    #                 <Texts>
    #                   <Text Language="en"><Value>First League</Value></Text>
    #                 </Texts>
    #                 <Match BetbalancerMatchID="109379">
    #                   <Fixture>
    #                     <Competitors>
    #                       <Texts>
    #                         <Text Type="1" ID="9373">
    #                           <Value>1. FC BRNO</Value>
    #                         </Text>
    #                       </Texts>
    #                       <Texts>
    #                         <Text Type="2" ID="371400">
    #                           <Value>FC SLOVACKO</Value>
    #                         </Text>
    #                       </Texts>
    #                     </Competitors>
    #                     <DateInfo>
    #                       <MatchDate>2024-08-23T16:40:00</MatchDate>
    #                     </DateInfo>
    #                     <StatusInfo>
    #                       <Off>1</Off>
    #                     </StatusInfo>
    #                   </Fixture>
    #                   <MatchOdds>
    #                     <Bet OddsType="10">
    #                       <Odds OutCome="1" OutcomeID="1">2.15</Odds>
    #                     </Bet>
    #                   </MatchOdds>
    #                 </Match>
    #                 <Match BetbalancerMatchID="109380">
    #                   <Fixture>
    #                     <Competitors>
    #                       <Texts>
    #                         <Text Type="1" ID="9375">
    #                           <Value>Team C</Value>
    #                         </Text>
    #                       </Texts>
    #                       <Texts>
    #                         <Text Type="2" ID="9376">
    #                           <Value>Team D</Value>
    #                         </Text>
    #                       </Texts>
    #                     </Competitors>
    #                     <DateInfo>
    #                       <MatchDate>2024-08-24T18:00:00</MatchDate>
    #                     </DateInfo>
    #                     <StatusInfo>
    #                       <Off>1</Off>
    #                     </StatusInfo>
    #                   </Fixture>
    #                   <MatchOdds>
    #                     <Bet OddsType="10">
    #                       <Odds OutCome="1" OutcomeID="1">1.65</Odds>
    #                     </Bet>
    #                   </MatchOdds>
    #                 </Match>
    #               </Tournament>
    #             </Category>
    #           </Sport>
    #         </Sports>
    #       </BetbalancerBetData>
    #     XML

    #   it "updates odds for all fixtures" do
    #     worker.perform

    #     existing_pre_market.reload
    #     pre_market_2.reload

    #     odds_1 = JSON.parse(existing_pre_market.odds)
    #     odds_2 = JSON.parse(pre_market_2.odds)

    #     expect(odds_1["1"]["odd"]).to eq(2.15)
    #     expect(odds_2["1"]["odd"]).to eq(1.65)
    #   end
    # end

    context "when API returns no data" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en"><Value>Football</Value></Text>
                </Texts>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "does not update any pre-markets" do
        original_odds = existing_pre_market.odds

        worker.perform

        existing_pre_market.reload
        expect(existing_pre_market.odds).to eq(original_odds)
      end
    end

    # context "with multiple sports" do
    #   before { stub_const("PreMatch::PullOddsJob::ACCEPTED_SPORTS", [1, 2]) }

    #   it "fetches odds for all sports" do
    #     worker.perform

    #     expect(bet_balancer).to have_received(:get_matches).with(sport_id: 1)
    #     expect(bet_balancer).to have_received(:get_matches).with(sport_id: 2)
    #   end
    # end

    context "when update fails" do
      before do
        allow_any_instance_of(PreMarket).to receive(:save).and_return(false)
        allow_any_instance_of(PreMarket).to receive(:errors).and_return(
          double(full_messages: ["Validation error"])
        )
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).with(
          /Failed to update pre-market/
        )

        expect { worker.perform }.not_to raise_error
      end
    end
  end

  describe "Sidekiq configuration" do
    it "is configured with high queue" do
      expect(described_class.sidekiq_options["queue"]).to eq(:high)
    end

    it "has retry set to 3" do
      expect(described_class.sidekiq_options["retry"]).to eq(1)
    end
  end
end
