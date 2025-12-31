WebSocket Integration Documentation
===================================

This document outlines the WebSocket channels available for real-time updates on fixtures and odds.

Connection Details
------------------
Base URL: ws://<YOUR_HOST>/cable (or wss:// for secure connections)
Protocol: ActionCable



--------------------------------------------------------------------------------


3. Deposit Channel
------------------
Purpose: Receive real-time updates when a deposit is created for a user.

Channel Name: DepositChannel


Authentication: Required. Only authenticated users can subscribe. The server will reject unauthorized connections.

Headers:
  - Authorization: Bearer <JWT_TOKEN>

The JWT token must be provided in the Authorization header when connecting to the WebSocket. Example:

  Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...


Parameters:
  - None (the user_id is inferred from the authenticated user; passing user_id is ignored or not required).

Subscription Request Example:
  {
    "command": "subscribe",
    "identifier": "{\"channel\":\"DepositChannel\"}"
  }

Stream Name: deposits_#{user.id}

Sample Update Message:
  {
    "deposit": {
      "id": 101,
      "currency": "UGX",
      "amount": 1000,
      "status": "pending",
      "balance_before": 5000,
      "balance_after": 6000,
      "transaction_id": "abc123",
      "created_at": "2025-12-31T12:00:00Z"
    }
  }

--------------------------------------------------------------------------------


4. Withdraws Channel
--------------------
Purpose: Receive real-time updates when a withdraw is created for a user.

Channel Name: WithdrawsChannel


Authentication: Required. Only authenticated users can subscribe. The server will reject unauthorized connections.

Headers:
  - Authorization: Bearer <JWT_TOKEN>

The JWT token must be provided in the Authorization header when connecting to the WebSocket. Example:

  Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...


Parameters:
  - None (the user_id is inferred from the authenticated user; passing user_id is ignored or not required).

Subscription Request Example:
  {
    "command": "subscribe",
    "identifier": "{\"channel\":\"WithdrawsChannel\"}"
  }

Stream Name: withdraws_#{user.id}

Sample Update Message:
  {
    "withdraw": {
      "id": 201,
      "currency": "UGX",
      "amount": 500,
      "status": "completed",
      "balance_before": 6000,
      "balance_after": 5500,
      "transaction_id": "def789",
      "created_at": "2025-12-31T12:05:00Z"
    }
  }

--------------------------------------------------------------------------------


1. Fixture Channel
------------------
Purpose: Receive general updates for a specific match (scores, status, time).

Channel Name: FixtureChannel

Authentication: Not required. Anyone can subscribe.

Parameters:
  - fixture_id (Required): The unique ID of the fixture.

Subscription Request Example:
  {
    "command": "subscribe",
    "identifier": "{\"channel\":\"FixtureChannel\",\"fixture_id\":\"12345\"}"
  }

Stream Name: fixture_#{fixture_id}

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

Authentication: Not required. Anyone can subscribe.

Parameters:
  - fixture_id (Required): The unique ID of the fixture.
  - market_identifier (Required): The external ID of the market (e.g., "1" for 1X2).

Subscription Request Example:
  {
    "command": "subscribe",
    "identifier": "{\"channel\":\"LiveOddsChannel\",\"fixture_id\":\"12345\",\"market_identifier\":\"1\"}"
  }

Stream Name: live_odds_#{market_identifier}_#{fixture_id}

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