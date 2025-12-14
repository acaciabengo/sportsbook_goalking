require "rails_helper"

RSpec.describe SyncSportsJob, type: :worker do
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
          </Sport>
          <Sport BetbalancerSportID="2">
            <Texts>
              <Text Language="en"><Value>Basketball</Value></Text>
            </Texts>
          </Sport>
        </Sports>
      </BetbalancerBetData>
    XML

  before do
    allow(BetBalancer).to receive(:new).and_return(bet_balancer)
    allow(bet_balancer).to receive(:get_sports).and_return(
      [200, Nokogiri.XML(xml_response)]
    )
  end

  describe "#perform" do
    context "when sports don't exist" do
      it "creates new sports from API data" do
        expect { worker.perform }.to change(Sport, :count).by(2)
      end

      it "creates sports with correct attributes" do
        worker.perform

        football = Sport.find_by(ext_sport_id: 1)
        basketball = Sport.find_by(ext_sport_id: 2)

        expect(football).to have_attributes(ext_sport_id: 1, name: "Football")

        expect(basketball).to have_attributes(
          ext_sport_id: 2,
          name: "Basketball"
        )
      end

      it "calls BetBalancer API" do
        worker.perform

        expect(bet_balancer).to have_received(:get_sports)
      end
    end

    context "when sport already exists" do
      let!(:existing_sport) do
        Fabricate(:sport, ext_sport_id: 1, name: "Football")
      end

      it "does not create duplicate sports" do
        expect { worker.perform }.to change(Sport, :count).by(1) # Only creates Basketball
      end

      it "does not update sport if name is unchanged" do
        original_updated_at = existing_sport.updated_at

        worker.perform

        existing_sport.reload
        expect(existing_sport.updated_at).to eq(original_updated_at)
      end
    end

    context "when sport exists but name has changed" do
      let!(:existing_sport) do
        Fabricate(:sport, ext_sport_id: 1, name: "Soccer")
      end

      it "updates the sport name" do
        worker.perform

        existing_sport.reload
        expect(existing_sport.name).to eq("Football")
      end

      it "does not create a new sport" do
        expect { worker.perform }.to change(Sport, :count).by(1) # Only Basketball is new
      end

      # it "updates the timestamp" do
      #   original_updated_at = existing_sport.updated_at

      #   Timecop.travel(1.minute.from_now) { worker.perform }

      #   existing_sport.reload
      #   expect(existing_sport.updated_at).to be > original_updated_at
      # end
    end

    context "when API returns empty data" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
            </Sports>
          </BetbalancerBetData>
        XML

      it "does not create any sports" do
        expect { worker.perform }.not_to change(Sport, :count)
      end
    end

    context "with sports containing special characters" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="10">
                <Texts>
                  <Text Language="en"><Value>E-Sports &amp; Gaming</Value></Text>
                </Texts>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "creates sport with special characters correctly" do
        worker.perform

        sport = Sport.find_by(ext_sport_id: 10)
        expect(sport.name).to eq("E-Sports & Gaming")
      end
    end

    context "when sport creation fails" do
      before do
        # Mock find_or_initialize_by to return a new record that fails to save
        failed_sport = Sport.new(ext_sport_id: 1, name: "Football")
        failed_sport.errors.add(:base, "Validation error")
        
        allow(Sport).to receive(:find_or_initialize_by).and_return(failed_sport)
        allow(failed_sport).to receive(:save).and_return(false)
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect { worker.perform }.not_to raise_error
      end

      it "does not create any sports" do
        expect { worker.perform }.not_to change(Sport, :count)
      end
    end

    context "when sport update fails" do
      let!(:existing_sport) do
        Fabricate(:sport, ext_sport_id: 1, name: "Old Name")
      end

      before do
        # Allow other calls to work normally
        allow(Sport).to receive(:find_or_initialize_by).and_call_original

        # Mock find_or_initialize_by to return the existing record
        allow(Sport).to receive(:find_or_initialize_by).with(ext_sport_id: 1).and_return(existing_sport)
        
        # Mock save to fail
        allow(existing_sport).to receive(:save).and_return(false)
        existing_sport.errors.add(:base, "Update validation error")
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect { worker.perform }.not_to raise_error
      end

      it "does not update the sport" do
        worker.perform

        existing_sport.reload
        expect(existing_sport.name).to eq("Old Name")
      end
    end

    context "with multiple sports with same ID" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en"><Value>Football</Value></Text>
                </Texts>
              </Sport>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en"><Value>Soccer</Value></Text>
                </Texts>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "creates only one sport with the last name" do
        expect { worker.perform }.to change(Sport, :count).by(1)

        sport = Sport.find_by(ext_sport_id: 1)
        expect(sport.name).to eq("Soccer")
      end
    end

    context "when API returns malformed XML" do
      before do
        allow(bet_balancer).to receive(:get_sports).and_raise(
          Nokogiri::XML::SyntaxError.new("Invalid XML")
        )
      end

      it "raises an error" do
        expect { worker.perform }.to raise_error(Nokogiri::XML::SyntaxError)
      end
    end

    context "when API returns sports without names" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                </Texts>
              </Sport>
              <Sport BetbalancerSportID="2">
                <Texts>
                  <Text Language="en"><Value>Basketball</Value></Text>
                </Texts>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      # it "skips sports without names" do
      #   expect { worker.perform }.to change(Sport, :count).by(1) # Only Basketball

      #   expect(Sport.find_by(ext_sport_id: 1)).to be_nil
      #   expect(Sport.find_by(ext_sport_id: 2)).to be_present
      # end
    end

    context "with very long sport names" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en"><Value>#{"A" * 500}</Value></Text>
                </Texts>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "handles long names appropriately" do
        worker.perform

        sport = Sport.find_by(ext_sport_id: 1)
        expect(sport.name.length).to eq(500)
      end
    end

    context "when BetBalancer API is unavailable" do
      before do
        allow(bet_balancer).to receive(:get_sports).and_raise(
          StandardError.new("Connection timeout")
        )
      end

      it "raises an error" do
        expect { worker.perform }.to raise_error(
          StandardError,
          "Connection timeout"
        )
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
