require "rails_helper"

RSpec.describe SyncCategoriesJob, type: :worker do
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
            <Category BetbalancerCategoryID="100" IsoName="CZE">
              <Texts>
                <Text Language="en"><Value>Czech Republic</Value></Text>
              </Texts>
            </Category>
            <Category BetbalancerCategoryID="101" IsoName="ESP">
              <Texts>
                <Text Language="en"><Value>Spain</Value></Text>
              </Texts>
            </Category>
          </Sport>
        </Sports>
      </BetbalancerBetData>
    XML

  let!(:sport) { Fabricate(:sport, ext_sport_id: 1, name: "Football") }

  before do
    allow(BetBalancer).to receive(:new).and_return(bet_balancer)
    allow(bet_balancer).to receive(:get_categories).and_return(
      [200, Nokogiri.XML(xml_response)]
    )
  end

  describe "#perform" do
    context "when categories don't exist" do
      it "creates new categories from API data" do
        expect { worker.perform }.to change(Category, :count).by(2)
      end

      it "creates categories with correct attributes" do
        worker.perform

        czech_category = Category.find_by(ext_category_id: 100)
        spain_category = Category.find_by(ext_category_id: 101)

        expect(czech_category).to have_attributes(
          ext_category_id: 100,
          name: "Czech Republic",
          sport_id: sport.id
        )

        expect(spain_category).to have_attributes(
          ext_category_id: 101,
          name: "Spain",
          sport_id: sport.id
        )
      end

      it "calls BetBalancer API for each sport" do
        worker.perform

        expect(bet_balancer).to have_received(:get_categories).with(sport_id: 1)
      end
    end

    context "when category already exists" do
      let!(:existing_category) do
        Fabricate(
          :category,
          ext_category_id: 100,
          name: "Czech Republic",
          sport: sport
        )
      end

      it "does not create duplicate categories" do
        expect { worker.perform }.to change(Category, :count).by(1) # Only creates the Spain category
      end

      it "does not update category if name is unchanged" do
        expect {
          worker.perform
          existing_category.reload
        }.not_to change(existing_category, :updated_at)
      end
    end

    context "when category exists but name has changed" do
      let!(:existing_category) do
        Fabricate(
          :category,
          ext_category_id: 100,
          name: "Old Czech Name",
          sport: sport
        )
      end

      it "updates the category name" do
        worker.perform

        existing_category.reload
        expect(existing_category.name).to eq("Czech Republic")
      end

      it "does not create a new category" do
        expect { worker.perform }.to change(Category, :count).by(1) # Only Spain is new
      end
    end

    context "with multiple sports" do
      let(:basketball_xml) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="2">
                <Texts>
                  <Text Language="en"><Value>Basketball</Value></Text>
                </Texts>
                <Category BetbalancerCategoryID="200" IsoName="USA">
                  <Texts>
                    <Text Language="en"><Value>USA</Value></Text>
                  </Texts>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      let!(:basketball_sport) do
        Fabricate(:sport, ext_sport_id: 2, name: "Basketball")
      end

      before do
        allow(bet_balancer).to receive(:get_categories).with(
          sport_id: 1
        ).and_return([200, Nokogiri.XML(xml_response)])
        allow(bet_balancer).to receive(:get_categories).with(
          sport_id: 2
        ).and_return([200, Nokogiri.XML(basketball_xml)])
      end

      it "creates categories for all sports" do
        expect { worker.perform }.to change(Category, :count).by(3)
      end

      it "associates categories with correct sports" do
        worker.perform

        football_categories = Category.where(sport: sport)
        basketball_categories = Category.where(sport: basketball_sport)

        expect(football_categories.count).to eq(2)
        expect(basketball_categories.count).to eq(1)
        expect(basketball_categories.first.name).to eq("USA")
      end

      it "calls API for each sport" do
        worker.perform

        expect(bet_balancer).to have_received(:get_categories).with(sport_id: 1)
        expect(bet_balancer).to have_received(:get_categories).with(sport_id: 2)
      end
    end

    context "when API returns empty data" do
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

      it "does not create any categories" do
        expect { worker.perform }.not_to change(Category, :count)
      end
    end

    context "when category creation fails" do
      before do
        allow_any_instance_of(Category).to receive(:save).and_return(false)
        allow_any_instance_of(Category).to receive(:errors).and_return(
          double(full_messages: ["Validation error"])
        )
      end

      it "logs the error and continues" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        expect { worker.perform }.not_to raise_error
      end
    end

    context "when category update fails" do
      let!(:existing_category) do
        Fabricate(
          :category,
          ext_category_id: 100,
          name: "Old Name",
          sport: sport
        )
      end

      before do
        allow_any_instance_of(Category).to receive(:update).and_return(false)
        allow_any_instance_of(Category).to receive(:errors).and_return(
          double(full_messages: ["Update validation error"])
        )
        allow(Rails.logger).to receive(:error)
      end

      # it "logs the error and continues" do
      #   expect(Rails.logger).to receive(:error).at_least(:once)

      #   expect { worker.perform }.not_to raise_error
      # end
    end

    context "when no sports exist" do
      before { Sport.destroy_all }

      it "does not call the API" do
        worker.perform

        expect(bet_balancer).not_to have_received(:get_categories)
      end

      it "does not create any categories" do
        expect { worker.perform }.not_to change(Category, :count)
      end
    end

    context "with categories containing special characters" do
      let(:xml_response) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="1">
                <Texts>
                  <Text Language="en"><Value>Football</Value></Text>
                </Texts>
                <Category BetbalancerCategoryID="100" IsoName="FRA">
                  <Texts>
                    <Text Language="en"><Value>Côte d'Ivoire</Value></Text>
                  </Texts>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      it "creates category with special characters correctly" do
        worker.perform

        category = Category.find_by(ext_category_id: 100)
        expect(category.name).to eq("Côte d'Ivoire")
      end
    end

    context "when same category ID exists for different sports" do
      let!(:basketball_sport) do
        Fabricate(:sport, ext_sport_id: 2, name: "Basketball")
      end

      let!(:existing_football_category) do
        Fabricate(
          :category,
          ext_category_id: 100,
          name: "Czech Republic Football",
          sport: sport
        )
      end

      let(:basketball_xml) { <<~XML }
          <?xml version="1.0" encoding="UTF-8"?>
          <BetbalancerBetData>
            <Sports>
              <Sport BetbalancerSportID="2">
                <Texts>
                  <Text Language="en"><Value>Basketball</Value></Text>
                </Texts>
                <Category BetbalancerCategoryID="100" IsoName="CZE">
                  <Texts>
                    <Text Language="en"><Value>Czech Republic Basketball</Value></Text>
                  </Texts>
                </Category>
              </Sport>
            </Sports>
          </BetbalancerBetData>
        XML

      before do
        allow(bet_balancer).to receive(:get_categories).with(
          sport_id: 1
        ).and_return([200, Nokogiri.XML(xml_response)])
        allow(bet_balancer).to receive(:get_categories).with(
          sport_id: 2
        ).and_return([200, Nokogiri.XML(basketball_xml)])
      end

      it "creates separate categories for different sports" do
        expect { worker.perform }.to change(Category, :count).by(2) # 2 new football + 1 basketball
      end

      it "keeps categories separated by sport" do
        worker.perform

        football_cat = Category.find_by(ext_category_id: 100, sport: sport)
        basketball_cat =
          Category.find_by(ext_category_id: 100, sport: basketball_sport)

        expect(football_cat.name).to eq("Czech Republic")
        expect(basketball_cat.name).to eq("Czech Republic Basketball")
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
