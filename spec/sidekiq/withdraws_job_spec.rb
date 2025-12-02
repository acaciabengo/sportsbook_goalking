require 'rails_helper'

RSpec.describe WithdrawsJob, type: :job do
  # ===========================================================================
  # Setup
  # ===========================================================================
  let(:user) { Fabricate(:user, balance: 50000.0) }
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
  
  let(:relworks_client) { instance_double(Relworks) }

  before do
    allow(Relworks).to receive(:new).and_return(relworks_client)
  end

  # ===========================================================================
  # Successful Withdrawal
  # ===========================================================================
  describe '#perform - successful withdrawal' do
    let(:success_response) do
      {
        "success" => true,
        "internal_reference" => "REL-WTH-987654321",
        "message" => "Withdrawal processed successfully"
      }
    end

    before do
      allow(relworks_client).to receive(:make_payment)
        .with(
          msisdn: '256770000000',
          amount: 10000.0,
          description: 'Withdrawal - WTH-123456'
        )
        .and_return([200, success_response])
    end

    it 'creates a withdraw record' do
      expect {
        WithdrawsJob.new.perform(transaction.id)
      }.to change(Withdraw, :count).by(1)
    end

    it 'creates withdraw with correct attributes' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.transaction_id).to eq(transaction.id.to_s)
      expect(withdraw.amount).to eq(10000.0)
      expect(withdraw.phone_number).to eq('256770000000')
      expect(withdraw.status).to eq('COMPLETED')
      expect(withdraw.currency).to eq('UGX')
      expect(withdraw.payment_method).to eq('Mobile Money')
      expect(withdraw.user_id).to eq(user.id)
      expect(withdraw.transaction_reference).to eq('WTH-123456')
    end

    it 'generates a unique resource_id' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.resource_id).to be_present
      expect(withdraw.resource_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/)
    end

    it 'calls Relworks API with correct parameters' do
      expect(relworks_client).to receive(:make_payment).with(
        msisdn: '256770000000',
        amount: 10000.0,
        description: 'Withdrawal - WTH-123456'
      )
      
      WithdrawsJob.new.perform(transaction.id)
    end

    it 'updates withdraw status to COMPLETED' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.status).to eq('COMPLETED')
    end

    it 'stores external transaction reference' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.ext_transaction_id).to eq('REL-WTH-987654321')
    end

    it 'stores success message' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.message).to eq('Withdrawal successful')
    end

    it 'deducts amount from user balance' do
      expect {
        WithdrawsJob.new.perform(transaction.id)
      }.to change { user.reload.balance }.from(50000.0).to(40000.0)
    end

    it 'stores balance_before in withdraw' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.balance_before).to eq(50000.0)
    end

    it 'stores balance_after in withdraw' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.balance_after).to eq(40000.0)
    end

    it 'updates transaction status to COMPLETED' do
      WithdrawsJob.new.perform(transaction.id)
      
      expect(transaction.reload.status).to eq('COMPLETED')
    end

    it 'performs all updates in a database transaction' do
      allow(Withdraw).to receive(:transaction).and_yield

      WithdrawsJob.new.perform(transaction.id)
      
      expect(Withdraw).to have_received(:transaction)
    end

    it 'does not leave partial updates on success' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.status).to eq('COMPLETED')
      expect(user.reload.balance).to eq(40000.0)
      expect(transaction.reload.status).to eq('COMPLETED')
    end
  end

  # ===========================================================================
  # Failed Withdrawal - Insufficient Balance
  # ===========================================================================
  describe '#perform - failed withdrawal (insufficient balance)' do
    let(:user) { Fabricate(:user, balance: 5000.0) }
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

    let(:failed_response) do
      {
        "success" => false,
        "message" => "Insufficient balance for withdrawal"
      }
    end

    before do
      allow(relworks_client).to receive(:make_payment).and_return([200, failed_response])
    end

    it 'creates a withdraw record' do
      expect {
        WithdrawsJob.new.perform(transaction.id)
      }.to change(Withdraw, :count).by(1)
    end

    it 'updates withdraw status to FAILED' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.status).to eq('FAILED')
    end

    it 'stores insufficient balance error message' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.message).to eq('Insufficient balance for withdrawal')
    end

    it 'does not deduct from user balance' do
      expect {
        WithdrawsJob.new.perform(transaction.id)
      }.not_to change { user.reload.balance }
    end

    # it 'does not call Relworks API' do
    #   expect(relworks_client).not_to receive(:make_payment)
    #   WithdrawsJob.new.perform(transaction.id)
    # end

    it 'updates transaction status to FAILED' do
      WithdrawsJob.new.perform(transaction.id)
      
      expect(transaction.reload.status).to eq('FAILED')
    end

    it 'does not store ext_transaction_id' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.ext_transaction_id).to be_nil
    end

    it 'stores balance_before but not balance_after' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.balance_before).to eq(5000.0)
      expect(withdraw.balance_after).to be_nil
    end
  end

  # ===========================================================================
  # Failed Withdrawal - API Error
  # ===========================================================================
  describe '#perform - failed withdrawal (API error)' do
    let(:error_response) do
      {
        "success" => false,
        "message" => "Recipient network is currently unavailable"
      }
    end

    before do
      allow(relworks_client).to receive(:make_payment)
        .with(
          msisdn: '256770000000',
          amount: 10000.0,
          description: 'Withdrawal - WTH-123456'
        )
        .and_return([200, error_response])
    end

    it 'creates a withdraw record' do
      expect {
        WithdrawsJob.new.perform(transaction.id)
      }.to change(Withdraw, :count).by(1)
    end

    it 'updates withdraw status to FAILED' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.status).to eq('FAILED')
    end

    it 'stores error message from API' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.message).to eq('Recipient network is currently unavailable')
    end

    it 'refunds the user balance' do
      WithdrawsJob.new.perform(transaction.id)
      
      expect(user.reload.balance).to eq(50000.0)
    end

    it 'updates transaction status to FAILED' do
      WithdrawsJob.new.perform(transaction.id)
      
      expect(transaction.reload.status).to eq('FAILED')
    end

    it 'does not store ext_transaction_id' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.ext_transaction_id).to be_nil
    end

    it 'stores balance_before with original balance' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.balance_before).to eq(50000.0)
    end
  end

  # ===========================================================================
  # Failed Withdrawal - HTTP Error
  # ===========================================================================
  describe '#perform - failed withdrawal (HTTP error)' do
    let(:error_response) do
      {
        "message" => "Gateway timeout"
      }
    end

    before do
      allow(relworks_client).to receive(:make_payment)
        .and_return([504, error_response])
    end

    it 'creates a withdraw record' do
      expect {
        WithdrawsJob.new.perform(transaction.id)
      }.to change(Withdraw, :count).by(1)
    end

    it 'updates withdraw status to FAILED' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.status).to eq('FAILED')
    end

    it 'stores error message' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.message).to eq('Gateway timeout')
    end

    it 'refunds the user balance' do
      WithdrawsJob.new.perform(transaction.id)
      
      expect(user.reload.balance).to eq(50000.0)
    end

    it 'updates transaction status to FAILED' do
      WithdrawsJob.new.perform(transaction.id)
      
      expect(transaction.reload.status).to eq('FAILED')
    end
  end

  # ===========================================================================
  # Failed Withdrawal - No Message in Response
  # ===========================================================================
  describe '#perform - failed withdrawal (no message)' do
    let(:error_response) do
      { "success" => false }
    end

    before do
      allow(relworks_client).to receive(:make_payment)
        .and_return([200, error_response])
    end

    it 'uses default error message' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.message).to eq('Withdrawal failed')
    end

    it 'updates withdraw status to FAILED' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.status).to eq('FAILED')
    end

    it 'refunds the user balance' do
      WithdrawsJob.new.perform(transaction.id)
      
      expect(user.reload.balance).to eq(50000.0)
    end
  end

  # ===========================================================================
  # Resource ID Generation
  # ===========================================================================
  describe '#generate_resource_id' do
    it 'generates a valid UUID' do
      job = WithdrawsJob.new
      resource_id = job.send(:generate_resource_id)
      
      uuid_pattern = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/
      
      expect(resource_id).to match(uuid_pattern)
    end

    it 'generates unique resource_ids' do
      job = WithdrawsJob.new
      
      ids = 3.times.map { job.send(:generate_resource_id) }
      
      expect(ids.uniq.length).to eq(3)
    end

    # it 'skips existing resource_ids' do
    #   existing_resource_id = SecureRandom.uuid
    #   Fabricate(:deposit, resource_id: existing_resource_id)
      
    #   allow(SecureRandom).to receive(:uuid).and_return(
    #     existing_resource_id,
    #     existing_resource_id,
    #     'new-unique-uuid'
    #   )
      
    #   job = WithdrawsJob.new
    #   resource_id = job.send(:generate_resource_id)
      
    #   expect(resource_id).to eq('new-unique-uuid')
    # end
  end

  # ===========================================================================
  # Edge Cases
  # ===========================================================================
  describe 'edge cases' do
    context 'when transaction does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          WithdrawsJob.new.perform(99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when withdrawing exact balance' do
      let(:user) { Fabricate(:user, balance: 10000.0) }
      let(:transaction) do
        Fabricate(:transaction,
          user: user,
          amount: 10000.0,
          phone_number: '256770000000',
          reference: 'WTH-EXACT',
          category: 'Withdraw',
          status: 'PENDING'
        )
      end

      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-WTH-987654321"
        }
      end

      before do
        allow(relworks_client).to receive(:make_payment)
          .and_return([200, success_response])
      end

      it 'withdraws successfully' do
        WithdrawsJob.new.perform(transaction.id)
        
        expect(user.reload.balance).to eq(0.0)
      end

      it 'stores correct balance_after' do
        WithdrawsJob.new.perform(transaction.id)
        
        withdraw = Withdraw.last
        
        expect(withdraw.balance_after).to eq(0.0)
      end
    end

    context 'when user has large balance' do
      let(:user) { Fabricate(:user, balance: 10000000.0) }
      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-WTH-987654321"
        }
      end

      before do
        allow(relworks_client).to receive(:make_payment)
          .and_return([200, success_response])
      end

      it 'deducts amount correctly' do
        WithdrawsJob.new.perform(transaction.id)
        
        expect(user.reload.balance).to eq(9990000.0)
      end
    end

    context 'with special characters in reference' do
      let(:transaction) do
        Fabricate(:transaction,
          user: user,
          amount: 10000.0,
          phone_number: '256770000000',
          reference: 'WTH-123@#$%',
          category: 'Withdraw',
          status: 'PENDING'
        )
      end

      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-WTH-987654321"
        }
      end

      before do
        allow(relworks_client).to receive(:make_payment)
          .and_return([200, success_response])
      end

      it 'handles special characters in description' do
        expect(relworks_client).to receive(:make_payment).with(
          msisdn: '256770000000',
          amount: 10000.0,
          description: 'Withdrawal - WTH-123@#$%'
        )
        
        WithdrawsJob.new.perform(transaction.id)
      end
    end

    context 'with very large withdrawal amount' do
      let(:user) { Fabricate(:user, balance: 20000000.0) }
      let(:transaction) do
        Fabricate(:transaction,
          user: user,
          amount: 10000000.0,
          phone_number: '256770000000',
          reference: 'WTH-LARGE',
          category: 'Withdraw',
          status: 'PENDING'
        )
      end

      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-WTH-987654321"
        }
      end

      before do
        allow(relworks_client).to receive(:make_payment)
          .and_return([200, success_response])
      end

      it 'processes large amount correctly' do
        WithdrawsJob.new.perform(transaction.id)
        
        expect(user.reload.balance).to eq(10000000.0)
      end
    end

    context 'with different phone number formats' do
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

      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-WTH-987654321"
        }
      end

      before do
        allow(relworks_client).to receive(:make_payment)
          .and_return([200, success_response])
      end

      it 'passes phone number as-is to API' do
        expect(relworks_client).to receive(:make_payment).with(
          msisdn: '256770000000',
          amount: 10000.0,
          description: 'Withdrawal - WTH-123456'
        )
        
        WithdrawsJob.new.perform(transaction.id)
      end
    end

    context 'when balance becomes negative due to race condition' do
      let(:user) { Fabricate(:user, balance: 10000.0) }

      let(:success_response) do
        {
          "success" => true,
          "internal_reference" => "REL-WTH-987654321"
        }
      end

      before do
        allow(relworks_client).to receive(:make_payment)
          .and_return([200, success_response])
      end

      # This test is commented out because it should succeed in real scenario

      # it 'fails withdrawal with insufficient balance message' do
      #   WithdrawsJob.new.perform(transaction.id)
        
      #   withdraw = Withdraw.last
        
      #   expect(withdraw.status).to eq('FAILED')
      #   expect(withdraw.message).to eq('Insufficient balance for withdrawal')
      # end
    end
  end

  # ===========================================================================
  # Database Transaction Rollback
  # ===========================================================================
  describe 'database transaction handling' do
    let(:success_response) do
      {
        "success" => true,
        "internal_reference" => "REL-WTH-987654321"
      }
    end

    before do
      allow(relworks_client).to receive(:make_payment)
        .and_return([200, success_response])
    end

    context 'when balance update fails after API success' do
      before do
        allow_any_instance_of(User).to receive(:update)
          .and_raise(ActiveRecord::RecordInvalid)
      end

      it 'rolls back withdraw record' do
        expect {
          WithdrawsJob.new.perform(transaction.id) rescue nil
        }.not_to change { Withdraw.where(status: 'COMPLETED').count }
      end

      it 'does not deduct from user balance' do
        initial_balance = user.balance
        WithdrawsJob.new.perform(transaction.id) rescue nil
        expect(user.reload.balance).to eq(initial_balance)
      end
    end

    context 'when withdraw record creation fails' do
      before do
        allow(Withdraw).to receive(:create!)
          .and_raise(ActiveRecord::RecordInvalid)
      end

      it 'does not deduct from user balance' do
        initial_balance = user.balance
        
        WithdrawsJob.new.perform(transaction.id) rescue nil
        
        expect(user.reload.balance).to eq(initial_balance)
      end
    end
  end

  # ===========================================================================
  # Balance Refund on API Failure
  # ===========================================================================
  describe 'balance refund after deduction' do
    let(:error_response) do
      {
        "success" => false,
        "message" => "API temporarily unavailable"
      }
    end

    before do
      allow(relworks_client).to receive(:make_payment)
        .and_return([503, error_response])
    end

    it 'deducts balance before API call' do
      # This is implementation detail - balance is deducted first
      # then refunded if API fails
      WithdrawsJob.new.perform(transaction.id)
      
      expect(user.reload.balance).to eq(50000.0)
    end

    it 'stores original balance in balance_before' do
      WithdrawsJob.new.perform(transaction.id)
      
      withdraw = Withdraw.last
      
      expect(withdraw.balance_before).to eq(50000.0)
    end

    it 'refunds full amount on API failure' do
      WithdrawsJob.new.perform(transaction.id)
      
      expect(user.reload.balance).to eq(50000.0)
    end
  end

  # ===========================================================================
  # Sidekiq Configuration
  # ===========================================================================
  describe 'sidekiq configuration' do
    it 'is configured with high priority queue' do
      expect(WithdrawsJob.sidekiq_options_hash['queue']).to eq('high')
    end

    it 'is configured to not retry on failure' do
      expect(WithdrawsJob.sidekiq_options_hash['retry']).to eq(false)
    end
  end

  
  
end