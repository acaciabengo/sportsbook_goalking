require "sidekiq"

class Pre::LiveScoresWorker
  include Sidekiq::Worker
  sidekiq_options queue: "high", retry: false

  def perform(message)
    soccer_status = {
      1 => "not_started",
      2 => "live",
      3 => "finished",
      4 => "cancelled",
      5 => "postponed",
      6 => "interrupted",
      7 => "Abandoned",
      8 => "coverage lost",
      9 => "about to start",
    }

    events = message.fetch("Body", {}).fetch("Events", nil)

    # exit if events is nil
    return if events.nil?

    events = [events] if events.is_a?(Hash)

    events.each do |event|
      event_id = event.fetch("FixtureId", nil)
      next if event_id.nil?

      # find fixture by event_id and next if fixture is nil
      fixture = Fixture.find_by(event_id: event_id)
      next if fixture.nil?

      #   find livescores update and update the scoreboard
      livescores = event.fetch("Livescore", nil)
      next if livescores.nil?

      livescores = [livescores] if livescores.is_a?(Hash)

      livescores.each do |score|
        status = score.fetch("Scoreboard", {}).fetch("Status", nil)
        match_time = score.fetch("Scoreboard", {}).fetch("Time", 0)

        update_attr = {
          status: soccer_status[status],
          match_time: "#{match_time / 60}:#{match_time % 60}",
          home_score: score.fetch("Scoreboard", {}).fetch("Results", [])[0].fetch("Value", nil),
          away_score: score.fetch("Scoreboard", {}).fetch("Results", [])[1].fetch("Value", nil),
        }

        fixture.update(update_attr)
      end
    end
  end
end
