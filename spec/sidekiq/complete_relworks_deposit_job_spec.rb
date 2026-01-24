require 'rails_helper'

RSpec.describe CompleteRelworksDepositJob, type: :job do
  let(:user) { Fabricate(:user, balance: 10000.0) }
  let(:transaction) do
    Fabricate(:transaction,
      user: user,
      amount: 5000.0,
      phone_number: '256770000000',
      reference: 'TXN-123456',
      category: 'Deposit',
      status: 'PENDING'
    )
  end
  let(:deposit) do
    Fabricate(:deposit,
      user: user,
      transaction_id: transaction.id,
      amount: 5000.0,
      phone_number: '256770000000',
      status: 'PENDING',
      ext_transaction_id: 'REL-EXT-123456789',
      currency: 'UGX',
      payment_method: 'Mobile Money',
      resource_id: SecureRandom.uuid,
      transaction_reference: transaction.reference
    )
  end

  describe '#perform - successful webhook' do
    let(:webhook_params) do
      {
        internal_reference: 'REL-EXT-123456789',
        status: 'success',
        message: 'Request payment completed successfully.',
        customer_reference: 'TXN-123456',
        msisdn: '+256770000000',
        amount: 5000.0,
        currency: 'UGX',
        provider: 'mtn_mobile_money',
        charge: 12.5,
        completed_at: '2025-04-10T15:12:58.977+03:00'
      }
    end

    before { deposit }

    it 'updates deposit status to COMPLETED' do
      CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])

      expect(deposit.reload.status).to eq('COMPLETED')
    end

    it 'updates user balance' do
      expect {
        CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])
      }.to change { user.reload.balance }.from(10000.0).to(15000.0)
    end

    it 'stores balance_after' do
      CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])

      expect(deposit.reload.balance_after).to eq(15000.0)
    end

    it 'updates transaction status to COMPLETED' do
      CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])

      expect(transaction.reload.status).to eq('COMPLETED')
    end

    it 'stores success message' do
      CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])

      expect(deposit.reload.message).to eq('Request payment completed successfully.')
    end
  end

  describe '#perform - failed webhook' do
    let(:webhook_params) do
      {
        internal_reference: 'REL-EXT-123456789',
        status: 'failed',
        message: 'Insufficient funds in mobile money account'
      }
    end

    before { deposit }

    it 'updates deposit status to FAILED' do
      CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])

      expect(deposit.reload.status).to eq('FAILED')
    end

    it 'does not update user balance' do
      expect {
        CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])
      }.not_to change { user.reload.balance }
    end

    it 'updates transaction status to FAILED' do
      CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])

      expect(transaction.reload.status).to eq('FAILED')
    end

    it 'stores error message' do
      CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])

      expect(deposit.reload.message).to eq('Insufficient funds in mobile money account')
    end
  end

  describe '#perform - deposit not found' do
    let(:webhook_params) do
      {
        internal_reference: 'NON-EXISTENT-REF',
        status: 'success'
      }
    end

    it 'logs error and returns early' do
      expect(Rails.logger).to receive(:error).with(/Deposit not found/)

      CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])
    end

    it 'does not raise error' do
      expect {
        CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])
      }.not_to raise_error
    end
  end

  describe '#perform - already completed deposit' do
    let(:webhook_params) do
      {
        internal_reference: 'REL-EXT-123456789',
        status: 'success'
      }
    end

    before do
      deposit.update!(status: 'COMPLETED', balance_after: 15000.0)
    end

    it 'returns early without changes' do
      expect {
        CompleteRelworksDepositJob.new.perform(webhook_params[:internal_reference], webhook_params[:status], webhook_params[:message])
      }.not_to change { user.reload.balance }
    end
  end

  describe 'sidekiq configuration' do
    it 'uses high priority queue' do
      expect(CompleteRelworksDepositJob.sidekiq_options_hash['queue']).to eq('high')
    end

    it 'retries 1 time' do
      expect(CompleteRelworksDepositJob.sidekiq_options_hash['retry']).to eq(1)
    end
  end
end
