require 'rails_helper'

RSpec.describe DepositsJob, type: :job do
  # ===========================================================================
  # Setup
  # ===========================================================================
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
  
  let(:relworks_client) { instance_double(Relworks) }

  before do
    allow(Relworks).to receive(:new).and_return(relworks_client)
  end

  # ===========================================================================
  # Successful Deposit
  # ===========================================================================
  describe '#perform - successful deposit' do
    let(:success_response) do
      {
        "success" => true,
        "internal_reference" => "REL-EXT-123456789",
        "message" => "Payment initiated successfully"
      }
    end

    before do
      allow(relworks_client).to receive(:request_payment)
        .with(
          msisdn: '256770000000',
          amount: 5000.0,
          description: 'Deposit - TXN-123456'
        )
        .and_return([200, success_response])
    end

    it 'creates a deposit record' do
      expect {
        DepositsJob.new.perform(transaction.id)
      }.to change(Deposit, :count).by(1)
    end

    it 'creates deposit with correct attributes' do
      DepositsJob.new.perform(transaction.id)

      deposit = Deposit.last

      expect(deposit.transaction_id).to eq(transaction.id.to_s)
      expect(deposit.amount).to eq(5000.0)
      expect(deposit.phone_number).to eq('256770000000')
      expect(deposit.status).to eq('PENDING')
      expect(deposit.currency).to eq('UGX')
      expect(deposit.payment_method).to eq('Mobile Money')
      expect(deposit.user_id).to eq(user.id)
      expect(deposit.transaction_reference).to eq('TXN-123456')
    end

    it 'generates a unique resource_id' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.resource_id).to be_present
      expect(deposit.resource_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it 'calls Relworks API with correct parameters' do
      expect(relworks_client).to receive(:request_payment).with(
        msisdn: '256770000000',
        amount: 5000.0,
        description: 'Deposit - TXN-123456'
      )
      
      DepositsJob.new.perform(transaction.id)
    end

    it 'updates deposit status to PENDING (awaiting webhook)' do
      DepositsJob.new.perform(transaction.id)

      deposit = Deposit.last

      expect(deposit.status).to eq('PENDING')
    end

    it 'stores external transaction reference' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.ext_transaction_id).to eq('REL-EXT-123456789')
    end

    it 'stores initiated message' do
      DepositsJob.new.perform(transaction.id)

      deposit = Deposit.last

      expect(deposit.message).to eq('Deposit initiated')
    end

    it 'does not update user balance (awaiting webhook)' do
      expect {
        DepositsJob.new.perform(transaction.id)
      }.not_to change { user.reload.balance }
    end

    it 'does not store balance_after (awaiting webhook)' do
      DepositsJob.new.perform(transaction.id)

      deposit = Deposit.last

      expect(deposit.balance_after).to be_nil
    end

    it 'updates transaction status to PENDING' do
      DepositsJob.new.perform(transaction.id)

      expect(transaction.reload.status).to eq('PENDING')
    end

    it 'performs all updates in a transaction' do
      allow(Deposit).to receive(:transaction).and_yield

      DepositsJob.new.perform(transaction.id)
      
      expect(Deposit).to have_received(:transaction)
    end

    it 'sets up deposit for webhook completion' do
      DepositsJob.new.perform(transaction.id)

      deposit = Deposit.last

      # Deposit is pending, waiting for webhook
      expect(deposit.status).to eq('PENDING')
      expect(deposit.ext_transaction_id).to eq('REL-EXT-123456789')
      expect(user.reload.balance).to eq(10000.0)
      expect(transaction.reload.status).to eq('PENDING')
    end
  end

  # ===========================================================================
  # Failed Deposit - API Returns Error
  # ===========================================================================
  describe '#perform - failed deposit (API error)' do
    let(:error_response) do
      {
        "success" => false,
        "message" => "Insufficient funds in mobile money account"
      }
    end

    before do
      allow(relworks_client).to receive(:request_payment)
        .with(
          msisdn: '256770000000',
          amount: 5000.0,
          description: 'Deposit - TXN-123456'
        )
        .and_return([200, error_response])
    end

    it 'creates a deposit record' do
      expect {
        DepositsJob.new.perform(transaction.id)
      }.to change(Deposit, :count).by(1)
    end

    it 'updates deposit status to FAILED' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.status).to eq('FAILED')
    end

    it 'stores error message from API' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.message).to eq('Insufficient funds in mobile money account')
    end

    it 'does not update user balance' do
      expect {
        DepositsJob.new.perform(transaction.id)
      }.not_to change { user.reload.balance }
    end

    it 'updates transaction status to FAILED' do
      DepositsJob.new.perform(transaction.id)
      
      expect(transaction.reload.status).to eq('FAILED')
    end

    it 'does not store ext_transaction_id' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.ext_transaction_id).to be_nil
    end

    it 'does not store balance_after' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.balance_after).to be_nil
    end
  end

  # ===========================================================================
  # Failed Deposit - HTTP Error
  # ===========================================================================
  describe '#perform - failed deposit (HTTP error)' do
    let(:error_response) do
      {
        "message" => "Service temporarily unavailable"
      }
    end

    before do
      allow(relworks_client).to receive(:request_payment)
        .and_return([500, error_response])
    end

    it 'creates a deposit record' do
      expect {
        DepositsJob.new.perform(transaction.id)
      }.to change(Deposit, :count).by(1)
    end

    it 'updates deposit status to FAILED' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.status).to eq('FAILED')
    end

    it 'stores error message' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.message).to eq('Service temporarily unavailable')
    end

    it 'does not update user balance' do
      expect {
        DepositsJob.new.perform(transaction.id)
      }.not_to change { user.reload.balance }
    end

    it 'updates transaction status to FAILED' do
      DepositsJob.new.perform(transaction.id)
      
      expect(transaction.reload.status).to eq('FAILED')
    end
  end

  # ===========================================================================
  # Failed Deposit - No Message in Response
  # ===========================================================================
  describe '#perform - failed deposit (no message)' do
    let(:error_response) do
      { "success" => false }
    end

    before do
      allow(relworks_client).to receive(:request_payment)
        .and_return([200, error_response])
    end

    it 'uses default error message' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.message).to eq('Deposit failed')
    end

    it 'updates deposit status to FAILED' do
      DepositsJob.new.perform(transaction.id)
      
      deposit = Deposit.last
      
      expect(deposit.status).to eq('FAILED')
    end
  end

  # ===========================================================================
  # Resource ID Generation
  # ===========================================================================
  describe '#generate_resource_id' do
    it 'generates a valid UUID' do
      job = DepositsJob.new
      resource_id = job.send(:generate_resource_id)
      
      uuid_pattern = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      
      expect(resource_id).to match(uuid_pattern)
    end

    it 'generates unique resource_ids' do
      job = DepositsJob.new
      
      ids = 3.times.map { job.send(:generate_resource_id) }
      
      expect(ids.uniq.length).to eq(3)
    end

    it 'skips existing resource_ids' do
      existing_resource_id = SecureRandom.uuid
      Fabricate(:withdraw, resource_id: existing_resource_id)
      
      allow(SecureRandom).to receive(:uuid).and_return(
        existing_resource_id,
        existing_resource_id,
        'new-unique-uuid'
      )
      
      job = DepositsJob.new
      resource_id = job.send(:generate_resource_id)
      
      expect(resource_id).to eq('new-unique-uuid')
    end
  end

  # ===========================================================================
  # Edge Cases
  # ===========================================================================
  describe 'edge cases' do
    context 'when transaction does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          DepositsJob.new.perform(99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when user has zero balance' do
      let(:user) { Fabricate(:user, balance: 0.0) }
      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-EXT-123456789"
        }
      end

      before do
        allow(relworks_client).to receive(:request_payment)
          .and_return([200, success_response])
      end

      it 'does not update balance (awaiting webhook)' do
        DepositsJob.new.perform(transaction.id)

        expect(user.reload.balance).to eq(0.0)
      end

      it 'stores ext_transaction_id for webhook lookup' do
        DepositsJob.new.perform(transaction.id)

        deposit = Deposit.last

        expect(deposit.ext_transaction_id).to eq('REL-EXT-123456789')
      end
    end

    context 'when user has large existing balance' do
      let(:user) { Fabricate(:user, balance: 1000000.0) }
      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-EXT-123456789"
        }
      end

      before do
        allow(relworks_client).to receive(:request_payment)
          .and_return([200, success_response])
      end

      it 'does not update balance (awaiting webhook)' do
        DepositsJob.new.perform(transaction.id)

        expect(user.reload.balance).to eq(1000000.0)
      end
    end

    context 'with special characters in reference' do
      let(:transaction) do
        Fabricate(:transaction,
          user: user,
          amount: 5000.0,
          phone_number: '256770000000',
          reference: 'TXN-123@#$%',
          category: 'Deposit',
          status: 'PENDING'
        )
      end

      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-EXT-123456789"
        }
      end

      before do
        allow(relworks_client).to receive(:request_payment)
          .and_return([200, success_response])
      end

      it 'handles special characters in description' do
        expect(relworks_client).to receive(:request_payment).with(
          msisdn: '256770000000',
          amount: 5000.0,
          description: 'Deposit - TXN-123@#$%'
        )
        
        DepositsJob.new.perform(transaction.id)
      end
    end

    context 'with very large amount' do
      let(:transaction) do
        Fabricate(:transaction,
          user: user,
          amount: 10000000.0,
          phone_number: '256770000000',
          reference: 'TXN-LARGE',
          category: 'Deposit',
          status: 'PENDING'
        )
      end

      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-EXT-123456789"
        }
      end

      before do
        allow(relworks_client).to receive(:request_payment)
          .and_return([200, success_response])
      end

      it 'creates deposit with large amount (awaiting webhook)' do
        DepositsJob.new.perform(transaction.id)

        deposit = Deposit.last
        expect(deposit.amount).to eq(10000000.0)
        expect(deposit.status).to eq('PENDING')
      end
    end

    context 'with different phone number formats' do
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

      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-EXT-123456789"
        }
      end

      before do
        allow(relworks_client).to receive(:request_payment)
          .and_return([200, success_response])
      end

      it 'passes phone number as-is to API' do
        expect(relworks_client).to receive(:request_payment).with(
          msisdn: '256770000000',
          amount: 5000.0,
          description: 'Deposit - TXN-123456'
        )
        
        DepositsJob.new.perform(transaction.id)
      end
    end
  end

  # ===========================================================================
  # Database Transaction Rollback
  # ===========================================================================
  describe 'database transaction handling' do
    let(:success_response) do
      {
        "success" => true,
        "internal_reference" => "REL-EXT-123456789"
      }
    end

    before do
      allow(relworks_client).to receive(:request_payment)
        .and_return([200, success_response])
    end

    context 'when deposit update fails' do
      before do
        allow_any_instance_of(Deposit).to receive(:update)
          .and_raise(ActiveRecord::RecordInvalid)
      end

      it 'does not leave deposit in inconsistent state' do
        expect {
          DepositsJob.new.perform(transaction.id) rescue nil
        }.not_to change { Deposit.where(status: 'PENDING', ext_transaction_id: 'REL-EXT-123456789').count }
      end
    end
  end

  # ===========================================================================
  # Sidekiq Configuration
  # ===========================================================================
  describe 'sidekiq configuration' do
    it 'is configured with high priority queue' do
      expect(DepositsJob.sidekiq_options_hash['queue']).to eq('high')
    end

    it 'is configured to not retry on failure' do
      expect(DepositsJob.sidekiq_options_hash['retry']).to eq(false)
    end
  end

  # ===========================================================================
  # Concurrent Deposits
  # ===========================================================================
  describe 'concurrent deposit handling' do
    require 'securerandom'
    # let!(:ext_id) { SecureRandom.uuid }
    # let(:success_response) do
    #   {
    #     "success" => true,
    #     "internal_reference" => ext_id
    #   }
    # end

    before (:each) do
      ext_id = SecureRandom.uuid
      allow(relworks_client).to receive(:request_payment)
        .and_return([200, {"success" => true, "internal_reference" => ext_id}])
    end

    # it 'handles multiple deposits for same user' do
    #   transaction2 = Fabricate(:transaction,
    #     user: user,
    #     amount: 3000.0,
    #     phone_number: '256770000000',
    #     reference: 'TXN-78901268',
    #     category: 'Deposit',
    #     status: 'PENDING'
    #   )

    #   DepositsJob.new.perform(transaction.id)
    #   DepositsJob.new.perform(transaction2.id)
      
    #   expect(user.reload.balance).to eq(18000.0)
    # end

    # it 'creates separate deposit records' do
    #   transaction2 = Fabricate(:transaction,
    #     user: user,
    #     amount: 3000.0,
    #     phone_number: '256770000000',
    #     reference: 'TXN-789012',
    #     category: 'Deposit',
    #     status: 'PENDING'
    #   )

    #   expect {
    #     DepositsJob.new.perform(transaction.id)
    #     DepositsJob.new.perform(transaction2.id)
    #   }.to change(Deposit, :count).by(2)
    # end
  end
end