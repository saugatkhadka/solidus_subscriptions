# frozen_string_literal: true

module CreateSubscription
  extend ActiveSupport::Concern
  include SolidusSubscriptions::SubscriptionLineItemBuilder

  included do
    after_action :handle_subscription_line_items, only: :create, if: :valid_subscription_line_item_params?
  end

  private

  def handle_subscription_line_items
    line_item = current_order.line_items.find_by(variant_id: params[:variant_id])
    create_subscription_line_item(line_item)
  end

  def valid_subscription_line_item_params?
    subscription_params = params[:subscription_line_item]
    %i[subscribable_id quantity interval_length].all? { |key| subscription_params[key].present? }
  end
end
