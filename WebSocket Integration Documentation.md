WebSocket Integration Documentation
===================================

This document outlines the WebSocket channels available for real-time updates on fixtures and odds.

Connection Details
------------------
Base URL: ws://<YOUR_HOST>/cable (or wss:// for secure connections)
Protocol: ActionCable

--------------------------------------------------------------------------------

1. Fixture Channel
------------------
Purpose: Receive general updates for a specific match (scores, status, time).

Channel Name: FixtureChannel

Parameters:
  - fixture_id (Required): The unique ID of the fixture.

Subscription Request Example:
  {
    "command": "subscribe",
    "identifier": "{\"channel\":\"FixtureChannel\",\"fixture_id\":\"12345\"}"
  }

Stream Name: fixture_<fixture_id>

Sample Update Message:
  {
    "id": 12345,
    "home_score": 1,
    "away_score": 0,
    "match_status": "in_play"
  }

--------------------------------------------------------------------------------

2. Live Odds Channel
--------------------
Purpose: Receive real-time odds updates for a specific market within a fixture.

Channel Name: LiveOddsChannel

Parameters:
  - fixture_id (Required): The unique ID of the fixture.
  - market_identifier (Required): The external ID of the market (e.g., "1" for 1X2).

Subscription Request Example:
  {
    "command": "subscribe",
    "identifier": "{\"channel\":\"LiveOddsChannel\",\"fixture_id\":\"12345\",\"market_identifier\":\"1\"}"
  }

Stream Name: live_odds_<market_identifier>_<fixture_id>

Sample Update Message:
  {
    "id": 1,
    "fixture_id": 12345,
    "market_identifier": "1",
    "odds": {
      "1": { "odd": 1.50, "outcome_id": 1001 },
      "X": { "odd": 3.20, "outcome_id": 1002 },
      "2": { "odd": 4.50, "outcome_id": 1003 }
    },
    "status": "active"
  }

--------------------------------------------------------------------------------