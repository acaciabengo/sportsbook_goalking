require "rails_helper"

RSpec.describe SyncTournamentsJob, type: :worker do
  let(:worker) { described_class.new }
  let(:bet_balancer) { instance_double(BetBalancer) }

  let!(:sport) { Fabricate(:sport, ext_sport_id: 1, name: "Football") }
  let!(:category) do
    Fabricate(
      :category,
      ext_category_id: 10,
      name: "Czech Republic",
      sport: sport
    )
  end

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
                </Match>
                <Match BetbalancerMatchID="109381">
                </Match>
              </Tournament>
              <Tournament BetbalancerTournamentID="101">
                <Texts>
                  <Text Language="en">
                    <Value>Second League</Value>
                  </Text>
                </Texts>
                <Match BetbalancerMatchID="109400">
                </Match>
              </Tournament>
            </Category>
          </Sport>
        </Sports>
      </BetbalancerBetData>
    XML

  before do
    allow(BetBalancer).to receive(:new).and_return(bet_balancer)
    allow(bet_balancer).to receive(:get_tournaments).and_return(
      Nokogiri.XML(xml_response)
    )
  end

  describe "#perform" do
    context "when tournaments don't exist" do
      it "creates new tournaments from API data" do
        expect { worker.perform }.to change(Tournament, :count).by(2)
      end

      it "creates tournaments with correct attributes" do
        worker.perform

        first_league = Tournament.find_by(ext_tournament_id: 100)
        second_league = Tournament.find_by(ext_tournament_id: 101)

        expect(first_league).to have_attributes(
          ext_tournament_id: 100,
          name: "First League",
          category_id: category.id
        )

        expect(second_league).to have_attributes(
          ext_tournament_id: 101,
          name: "Second League",
          category_id: category.id
        )
      end

      it "calls BetBalancer API for each category" do
        worker.perform

        expect(bet_balancer).to have_received(:get_tournaments).with(
          category_id: 10
        )
      end
    end

    context "when tournament already exists" do
      let!(:existing_tournament) do
        Fabricate(
          :tournament,
          ext_tournament_id: 100,
          name: "First League",
          category: category
        )
      end

      it "does not create duplicate tournaments" do
        expect { worker.perform }.to change(Tournament, :count).by(1) # Only creates Second League
      end

      it "does not update tournament if name is unchanged" do
        original_updated_at = existing_tournament.updated_at

        worker.perform

        existing_tournament.reload
        expect(existing_tournament.updated_at).to eq(original_updated_at)
      end
    end

    context "when tournament exists but name has changed" do
      let!(:existing_tournament) do
        Fabricate(
          :tournament,
          ext_tournament_id: 100,
          name: "Old First League",
          category: category
        )
      end

      it "updates the tournament name" do
        worker.perform

        existing_tournament.reload
        expect(existing_tournament.name).to eq("First League")
      end

      it "does not create a new tournament" do
        expect { worker.perform }.to change(Tournament, :count).by(1) # Only Second League is new
      end

      # it "updates the timestamp" do
      #   original_updated_at = existing_tournament.updated_at

      #   Timecop.travel(1.minute.from_now) { worker.perform }

      #   existing_tournament.reload
      #   expect(existing_tournament.updated_at).to be > original_updated_at
      # end
    end

    context "with multiple categories" do
      let!(:poland_category) do
        Fabricate(:category, ext_category_id: 20, name: "Poland", sport: sport)
      end

      let(:poland_xml) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en">
                    <Value>Football</Value>
                  </Text>
                </Texts>
                <Category BetbalancerCategoryID="20" IsoName="POL">
                  <Texts>
                    <Text Language="en">
                      <Value>Poland</Value>
                    </Text>
                  </Texts>
                  <Tournament BetbalancerTournamentID="200">
                    <Texts>
                      <Text Language="en">
                        <Value>Ekstraklasa</Value>
                      </Text>
                    </Texts>
                  </Tournament>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      before do
        allow(bet_balancer).to receive(:get_tournaments).with(
          category_id: 10
        ).and_return(Nokogiri.XML(xml_response))

        allow(bet_balancer).to receive(:get_tournaments).with(
          category_id: 20
        ).and_return(Nokogiri.XML(poland_xml))
      end

      it "creates tournaments for all categories" do
        expect { worker.perform }.to change(Tournament, :count).by(3)
      end

      it "associates tournaments with correct categories" do
        worker.perform

        czech_tournaments = Tournament.where(category: category)
        poland_tournaments = Tournament.where(category: poland_category)

        expect(czech_tournaments.count).to eq(2)
        expect(poland_tournaments.count).to eq(1)
        expect(poland_tournaments.first.name).to eq("Ekstraklasa")
      end

      it "calls API for each category" do
        worker.perform

        expect(bet_balancer).to have_received(:get_tournaments).with(
          category_id: 10
        )
        expect(bet_balancer).to have_received(:get_tournaments).with(
          category_id: 20
        )
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
                <Category BetbalancerCategoryID="10" IsoName="CZE">
                  <Texts>
                    <Text Language="en">
                      <Value>Czech Republic</Value>
                    </Text>
                  </Texts>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "does not create any tournaments" do
        expect { worker.perform }.not_to change(Tournament, :count)
      end
    end

    context "when tournament creation fails" do
      before do
        # Create a failed tournament with real errors
        failed_tournament = Tournament.new
        failed_tournament.errors.add(:base, "Validation error")

        allow(failed_tournament).to receive(:persisted?).and_return(false)
        allow(Tournament).to receive(:create).and_return(failed_tournament)
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect { worker.perform }.not_to raise_error
      end
    end

    context "when tournament update fails" do
      let!(:existing_tournament) do
        Fabricate(
          :tournament,
          ext_tournament_id: 100,
          name: "Old Name",
          category: category
        )
      end

      before do
        # Create a tournament with real errors
        tournament_with_errors = Tournament.new
        tournament_with_errors.errors.add(:base, "Update validation error")

        allow_any_instance_of(Tournament).to receive(:update).and_return(false)
        allow_any_instance_of(Tournament).to receive(:errors).and_return(
          tournament_with_errors.errors
        )
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect { worker.perform }.not_to raise_error
      end
    end

    context "when no categories exist" do
      before { Category.destroy_all }

      it "does not call the API" do
        worker.perform

        expect(bet_balancer).not_to have_received(:get_tournaments)
      end

      it "does not create any tournaments" do
        expect { worker.perform }.not_to change(Tournament, :count)
      end
    end

    context "with tournaments containing special characters" do
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
                <Category BetbalancerCategoryID="10" IsoName="FRA">
                  <Texts>
                    <Text Language="en">
                      <Value>France</Value>
                    </Text>
                  </Texts>
                  <Tournament BetbalancerTournamentID="100">
                    <Texts>
                      <Text Language="en">
                        <Value>Ligue 1 &amp; Cup</Value>
                      </Text>
                    </Texts>
                  </Tournament>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "creates tournament with special characters correctly" do
        worker.perform

        tournament = Tournament.find_by(ext_tournament_id: 100)
        expect(tournament.name).to eq("Ligue 1 & Cup")
      end
    end

    context "when same tournament ID exists for different categories" do
      let!(:poland_category) do
        Fabricate(:category, ext_category_id: 20, name: "Poland", sport: sport)
      end

      let!(:existing_czech_tournament) do
        Fabricate(
          :tournament,
          ext_tournament_id: 100,
          name: "Czech Division 1",
          category: category
        )
      end

      let(:poland_xml) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en">
                    <Value>Football</Value>
                  </Text>
                </Texts>
                <Category BetbalancerCategoryID="20" IsoName="POL">
                  <Texts>
                    <Text Language="en">
                      <Value>Poland</Value>
                    </Text>
                  </Texts>
                  <Tournament BetbalancerTournamentID="100">
                    <Texts>
                      <Text Language="en">
                        <Value>Poland Division 1</Value>
                      </Text>
                    </Texts>
                  </Tournament>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      before do
        allow(bet_balancer).to receive(:get_tournaments).with(
          category_id: 10
        ).and_return(Nokogiri.XML(xml_response))

        allow(bet_balancer).to receive(:get_tournaments).with(
          category_id: 20
        ).and_return(Nokogiri.XML(poland_xml))
      end

      it "creates separate tournaments for different categories" do
        expect { worker.perform }.to change(Tournament, :count).by(2) # 2 Czech + 1 Poland
      end

      it "keeps tournaments separated by category" do
        worker.perform

        czech_tournaments =
          Tournament.where(category: category, ext_tournament_id: 100)
        poland_tournaments =
          Tournament.where(category: poland_category, ext_tournament_id: 100)

        expect(czech_tournaments.count).to eq(1)
        expect(poland_tournaments.count).to eq(1)
        expect(czech_tournaments.first.name).to eq("First League")
        expect(poland_tournaments.first.name).to eq("Poland Division 1")
      end
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
