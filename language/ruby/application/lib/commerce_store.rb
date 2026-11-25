module CommerceCopilot
  class CommerceStore
    CATALOG = [
      {
        'sku' => 'sku-100', 'name' => 'Starter plan', 'price_cents' => 4_900,
        'stock' => 10, 'tags' => %w[plan starter]
      },
      {
        'sku' => 'sku-200', 'name' => 'Pro plan', 'price_cents' => 9_900,
        'stock' => 0, 'tags' => %w[plan pro]
      },
      {
        'sku' => 'sku-300', 'name' => 'Analytics add-on', 'price_cents' => 1_900,
        'stock' => 5, 'tags' => %w[addon analytics]
      }
    ].freeze

    def initialize
      @mutex = Mutex.new
      @orders = {}
      @charges = 0
      @refunds = 0
    end

    def search(query)
      needle = query.to_s.downcase
      @mutex.synchronize do
        CATALOG.select do |item|
          needle.empty? || item['name'].downcase.include?(needle) ||
            item['tags'].any? { |tag| tag.include?(needle) }
        end.map(&:dup)
      end
    end

    def quote(items)
      raise 'CART_EMPTY' if !items.is_a?(Array) || items.empty?

      line_items = items.map do |item|
        sku = item['sku'].to_s
        product = CATALOG.find { |entry| entry['sku'] == sku }
        raise "SKU_NOT_FOUND: #{sku}" if product.nil?

        quantity = Integer(item['quantity'] || 0)
        raise 'QUANTITY_INVALID' unless quantity.positive?

        {
          'sku' => sku, 'name' => product['name'], 'quantity' => quantity,
          'unit_price_cents' => product['price_cents'],
          'line_total_cents' => product['price_cents'] * quantity,
          'available' => product['stock'] >= quantity
        }
      end
      subtotal = line_items.sum { |item| item['line_total_cents'] }
      tax = (subtotal * 0.08).round
      {
        'items' => line_items, 'subtotal_cents' => subtotal,
        'tax_cents' => tax, 'total_cents' => subtotal + tax,
        'in_stock' => line_items.all? { |item| item['available'] }
      }
    end

    def draft_order(tenant:, items:, diagnosis:, rationale:)
      quotation = quote(items)
      raise 'CART_NOT_IN_STOCK' unless quotation['in_stock']
      raise 'DIAGNOSIS_REQUIRED' if diagnosis.to_s.strip.empty?
      raise 'RATIONALE_REQUIRED' if rationale.to_s.strip.empty?

      @mutex.synchronize do
        order_id = "draft-#{@orders.length + 1}"
        order = {
          'order_id' => order_id, 'tenant' => tenant, 'items' => items,
          'quote' => quotation, 'diagnosis' => diagnosis,
          'rationale' => rationale, 'status' => 'draft_only',
          'review_required' => true, 'payment_status' => 'not_charged',
          'payment_charges' => 0, 'refunds' => 0
        }
        @orders[order_id] = order
        order.dup
      end
    end

    def record_charge(tenant:, order_id:)
      @mutex.synchronize { @charges += 1 }
      { 'tenant' => tenant, 'order_id' => order_id, 'charged' => true }
    end

    def record_refund(tenant:, order_id:)
      @mutex.synchronize { @refunds += 1 }
      { 'tenant' => tenant, 'order_id' => order_id, 'refunded' => true }
    end

    def counts
      @mutex.synchronize do
        { 'drafts' => @orders.length, 'charges' => @charges, 'refunds' => @refunds }
      end
    end
  end
end
