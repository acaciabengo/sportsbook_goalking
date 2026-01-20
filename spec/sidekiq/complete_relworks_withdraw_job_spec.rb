require 'rails_helper'

RSpec.describe CompleteRelworksWithdrawJob, type: :job do
  let(:user) { Fabricate(:user, balance: 40000.0) }
  let(:transaction) do
    Fabricate(:transaction,
      user: user,
      amount: 10000.0,
      phone_number: '256770000000',
      reference: 'WTH-123456',
      category: 'Withdraw',
      status: 'PENDING'
    )
  end
  let(:withdraw) do
    Fabricate(:withdraw,
      user: user,
      transaction_id: transaction.id,
      amount: 10000.0,
      phone_number: '256770000000',
      status: 'PENDING',
      ext_transaction_id: 'REL-WTH-987654321',
      currency: 'UGX',
      payment_method: 'Mobile Money',
      resource_id: SecureRandom.uuid,
      balance_before: 50000.0,
      transaction_reference: transaction.reference
    )
  end

  describe '#perform - successful webhook' do
    let(:webhook_params) do
      {
        internal_reference: 'REL-WTH-987654321',
        status: 'success',
        message: 'Send payment completed successfully.',
        customer_reference: 'WTH-123456',
        msisdn: '+256770000000',
        amount: 10000.0,
        currency: 'UGX',
        provider: 'mtn_mobile_money',
        charge: 25.0,
        completed_at: '2025-04-10T15:12:58.977+03:00'
      }
    end

    before { withdraw }

    it 'updates withdraw status to COMPLETED' do
      CompleteRelworksWithdrawJob.new.perform(**webhook_params)

      expect(withdraw.reload.status).to eq('COMPLETED')
    end

    it 'does not change user balance (already deducted)' do
      expect {
        CompleteRelworksWithdrawJob.new.perform(**webhook_params)
      }.not_to change { user.reload.balance }
    end

    it 'stores balance_after' do
      CompleteRelworksWithdrawJob.new.perform(**webhook_params)

      expect(withdraw.reload.balance_after).to eq(40000.0)
    end

    it 'updates transaction status to COMPLETED' do
      CompleteRelworksWithdrawJob.new.perform(**webhook_params)

      expect(transaction.reload.status).to eq('COMPLETED')
    end

    it 'stores success message' do
      CompleteRelworksWithdrawJob.new.perform(**webhook_params)

      expect(withdraw.reload.message).to eq('Send payment completed successfully.')
    end
  end

  describe '#perform - failed webhook' do
    let(:webhook_params) do
      {
        internal_reference: 'REL-WTH-987654321',
        status: 'failed',
        message: 'Recipient network unavailable'
      }
    end

    before { withdraw }

    it 'updates withdraw status to FAILED' do
      CompleteRelworksWithdrawJob.new.perform(**webhook_params)

      expect(withdraw.reload.status).to eq('FAILED')
    end

    it 'refunds user balance' do
      expect {
        CompleteRelworksWithdrawJob.new.perform(**webhook_params)
      }.to change { user.reload.balance }.from(40000.0).to(50000.0)
    end

    it 'updates transaction status to FAILED' do
      CompleteRelworksWithdrawJob.new.perform(**webhook_params)

      expect(transaction.reload.status).to eq('FAILED')
    end

    it 'stores error message' do
      CompleteRelworksWithdrawJob.new.perform(**webhook_params)

      expect(withdraw.reload.message).to eq('Recipient network unavailable')
    end
  end

  describe '#perform - withdraw not found' do
    let(:webhook_params) do
      {
        internal_reference: 'NON-EXISTENT-REF',
        status: 'success'
      }
    end

    it 'logs error and returns early' do
      expect(Rails.logger).to receive(:error).with(/Withdraw not found/)

      CompleteRelworksWithdrawJob.new.perform(**webhook_params)
    end

    it 'does not raise error' do
      expect {
        CompleteRelworksWithdrawJob.new.perform(**webhook_params)
      }.not_to raise_error
    end
  end

  describe '#perform - already completed withdraw' do
    let(:webhook_params) do
      {
        internal_reference: 'REL-WTH-987654321',
        status: 'success'
      }
    end

    before do
      withdraw.update!(status: 'COMPLETED', balance_after: 40000.0)
    end

    it 'returns early without changes' do
      expect {
        CompleteRelworksWithdrawJob.new.perform(**webhook_params)
      }.not_to change { user.reload.balance }
    end
  end

  describe 'sidekiq configuration' do
    it 'uses high priority queue' do
      expect(CompleteRelworksWithdrawJob.sidekiq_options_hash['queue']).to eq('high')
    end

    it 'retries 3 times' do
      expect(CompleteRelworksWithdrawJob.sidekiq_options_hash['retry']).to eq(3)
    end
  end
end
