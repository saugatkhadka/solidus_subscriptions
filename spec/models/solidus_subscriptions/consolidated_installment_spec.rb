require 'rails_helper'

RSpec.describe SolidusSubscriptions::ConsolidatedInstallment do
  let(:consolidated_installment) { described_class.new(installments) }
  let(:installments) { create_list(:installment, 2) }

  describe '#process', :checkout do
    subject(:order) { consolidated_installment.process }
    let(:subscription_line_item) { installments.first.subscription.line_item }

    shared_examples 'a completed checkout' do
      it { is_expected.to be_a Spree::Order }

      it 'has the correct number of line items' do
        count = order.line_items.length
        expect(count).to eq installments.length
      end

      it 'the line items have the correct values' do
        line_item = order.line_items.first
        expect(line_item).to have_attributes(
          quantity: subscription_line_item.quantity,
          variant_id: subscription_line_item.subscribable_id
        )
      end

      it 'has a shipment' do
        expect(order.shipments).to be_present
      end

      it 'has a payment' do
        expect(order.payments.valid).to be_present
      end

      it 'has the correct totals' do
        expect(order).to have_attributes(
          total: 49.98,
          shipment_total: 10
        )
      end

      it { is_expected.to be_complete }
    end

    context 'the user has addresss and active card' do
      let(:credit_card) { create(:credit_card, gateway_customer_profile_id: 'BGS-123', default: true) }

      before do
        consolidated_installment.user.credit_cards << credit_card
        consolidated_installment.user.update ship_address: create(:address)
      end

      it_behaves_like 'a completed checkout'

      it 'uses the root order address' do
        expect(order.ship_address).to eq consolidated_installment.user.ship_address
      end

      it 'uses the root orders last payment method' do
        source = order.payments.last.source
        expect(source).to eq credit_card
      end
    end

    context 'the user has no address or active card' do
      it_behaves_like 'a completed checkout'

      it 'uses the root order address' do
        expect(order.ship_address).to eq consolidated_installment.root_order.ship_address
      end

      it 'uses the root orders last payment method' do
        source = order.payments.last.source
        expect(source).to eq consolidated_installment.root_order.payments.last.source
      end
    end

    context 'the variant is out of stock' do
      # Remove stock for 1 variant in the consolidated installment
      before do
        subscribable_id = installments.first.subscription.line_item.subscribable_id
        variant = Spree::Variant.find(subscribable_id)
        variant.stock_items.update_all(count_on_hand: 0, backorderable: false)
      end

      it 'creates an installment detail' do
        expect { subject }.
          to change { SolidusSubscriptions::InstallmentDetail.count }.
          by(1)
      end

      it 'creates a failed installment detail' do
        subject
        detail = SolidusSubscriptions::InstallmentDetail.last

        expect(detail).to_not be_successful
        expect(detail.message).
          to eq I18n.t('solidus_subscriptions.installment_details.out_of_stock')
      end

      it 'removes the installment from the list of installments' do
        expect { subject }.
          to change { consolidated_installment.installments.length }.
          by(-1)
      end
    end
  end

  describe '#order' do
    subject { consolidated_installment.order }
    let(:user) { installments.first.subscription.user }
    let(:root_order) { installments.first.subscription.root_order }

    it { is_expected.to be_a Spree::Order }

    it 'has the correct attributes' do
      expect(subject).to have_attributes(
        user: user,
        email: user.email,
        store: root_order.store
      )
    end

    it 'is the same instance any time its called' do
      order = consolidated_installment.order
      expect(subject).to equal order
    end
  end
end
