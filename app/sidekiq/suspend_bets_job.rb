class SuspendBetsJob
  include Sidekiq::Job
  sidekiq_options queue: "high"
  sidekiq_options retry: false

  def perform(fixture_id, product, market_id, specifier)
    #find the fixture
    fixture = Fixture.find(fixture_id)
    bets =
      fixture.bets.where(
        product: product,
        market_identifier: market_id,
        status: "Active",
        specifier: specifier
      )

    bets.update_all(result: "Void", status: "Closed")
  end
end
