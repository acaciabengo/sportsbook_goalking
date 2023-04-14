require "rails_helper"
require "sidekiq/testing"
Sidekiq::Testing.fake!

RSpec.describe FixtureChangeWorker, type: :worker do
  describe "#perform" do
    let(:worker) { FixtureChangeWorker.new }
    let(:message) { { "Body" => { "Events" => events } } }
    let(:product) { "test_product" }
    let(:events) { [{ "FixtureId" => 1, "Fixture" => fixture_data }] }
    let(:fixture_data) do
      {
        "StartDate" => "2023-05-01T00:00:00Z",
        "Status" => "scheduled",
        "ExternalProviderId" => 123,
        "League" => { "Id" => 1, "Name" => "Test League" },
        "Sport" => { "Id" => 2, "Name" => "Test Sport" },
        "Location" => { "Id" => 3, "Name" => "Test Location" },
        "Participants" => [
          { "Participant" => { "Id" => 4, "Name" => "Test Participant 1" } },
          { "Participant" => { "Id" => 5, "Name" => "Test Participant 2" } },
        ],
      }
    end

    before do
      allow(Fixture).to receive(:find_or_initialize_by).and_return(fixture)
    end

    context "when events is nil" do
      let(:events) { nil }
      let(:fixture) { double(:fixture) }

      it "does not save a fixture" do
        expect(fixture).not_to receive(:save)
        worker.perform(message, product)
      end
    end

    context "when events is an empty array" do
      let(:events) { [] }
      let(:fixture) { double(:fixture) }

      it "does not save a fixture" do
        expect(fixture).not_to receive(:save)
        worker.perform(message, product)
      end
    end

    context "when events is a hash" do
      let(:events) { { "FixtureId" => 1, "Fixture" => fixture_data } }
      let(:fixture) { double(:fixture) }

      it "wraps the hash in an array and saves a fixture" do
        expect(Fixture).to receive(:find_or_initialize_by).with(event_id: 1).and_return(fixture)
        expect(fixture).to receive(:assign_attributes).with(
          start_date: "2023-05-01T00:00:00Z",
          status: "scheduled",
          ext_provider_id: 123,
          league_id: 1,
          league_name: "Test League",
          sport_id: 2,
          sport: "Test Sport",
          location_id: 3,
          location: "Test Location",
          part_one_id: 4,
          part_one_name: "Test Participant 1",
          part_two_id: 5,
          part_two_name: "Test Participant 2",
        )
        expect(fixture).to receive(:save)
        worker.perform(message, product)
      end
    end

    context "when events is an array of hashes" do
      let(:fixture) { double(:fixture) }

      it "saves a fixture for each event" do
        events.each do |event|
          expect(Fixture).to receive(:find_or_initialize_by).with(event_id: event["FixtureId"]).and_return(fixture)
          expect(fixture).to receive(:assign_attributes).with(
            start_date: "2023-05-01T00:00:00Z",
            status: "scheduled",
            ext_provider_id: 123,
            league_id: 1,
            league_name: "Test League",
            sport_id: 2,
            sport: "Test Sport",
            location_id: 3,
            location: "Test Location",
            part_one_id: 4,
            part_one_name: "Test Participant 1",
            part_two_id: 5,
            part_two_name: "Test Participant 2",
          )
          expect(fixture).to receive(:save)
          worker.perform(message, product)
        end
      end
    end
  end
end
