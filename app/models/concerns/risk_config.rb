module RiskConfig
  # Global exposure limits
  MAX_WIN_PER_BET = 50_000_000  # UGX
  MAX_WIN_PER_PLAYER_PER_DAY = 120_000_000  # UGX

  # Stake limits by tier and bet type
  STAKE_LIMITS = {
    'A' => { singles: 2_000_000, parlays: 1_000_000, sgm: 500_000 },
    'B' => { singles: 500_000, parlays: 300_000, sgm: 100_000 },
    'C' => { singles: 150_000, parlays: 50_000, sgm: 25_000 },
    'D' => { singles: 50_000, parlays: 15_000, sgm: 10_000 }
  }.freeze

  # SGM restrictions
  SGM_ALLOWED_MARKETS = ['1', '10', '11', '29', '92'].freeze
  SGM_ALLOWED_GOAL_LINES = ['1.5', '2.5', '3.5', '4.5'].freeze
  SGM_MAX_LEGS = 4

  # Calculate tier from net winnings over last 7 days
  def self.calculate_tier(net_winnings_7d)
    return 'D' if net_winnings_7d > 4_000_000
    return 'C' if net_winnings_7d > 2_000_000
    return 'B' if net_winnings_7d > 500_000
    'A'
  end
end
