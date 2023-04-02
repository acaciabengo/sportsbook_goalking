require "sidekiq"

class Live::FixtureChangeWorker
  include Sidekiq::Worker
  sidekiq_options queue: "critical"
  sidekiq_options retry: false

  def perform(message)
    events = message.fetch("Body", {}).fetch("Events", nil)
    # exit if events is nil
    return if events.nil?

    events = [events] if events.is_a?(Hash)

    events.each do |event|
      event_id = event.fetch("FixtureId", nil)
      next if event_id.nil?

      fixture = Fixture.find_or_initialize_by(event_id: event_id)

      fixture.assign_attributes(
        start_date: event.dig("Fixture", "StartDate"),
        status: event.dig("Fixture", "Status"),
        ext_provider_id: event.dig("Fixture", "ExternalProviderId"),
        league_id: event.dig("Fixture", "League", "Id"),
        league_name: event.dig("Fixture", "League", "Name"),
        sport_id: event.dig("Fixture", "Sport", "Id"),
        sport: event.dig("Fixture", "Sport", "Name"),
        location_id: event.dig("Fixture", "Location", "Id"),
        location: event.dig("Fixture", "Location", "Name"),
        part_one_id: event.dig("Fixture", "Participants", 0, "Participant", "Id"),
        part_one_name: event.dig("Fixture", "Participants", 0, "Participant", "Name"),
        part_two_id: event.dig("Fixture", "Participants", 1, "Participant", "Id"),
        part_two_name: event.dig("Fixture", "Participants", 1, "Participant", "Name"),
      )
      fixture.save
    end
  end
end
