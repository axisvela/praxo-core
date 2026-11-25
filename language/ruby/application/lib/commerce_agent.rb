require 'json'
require 'open3'
require 'praxo'
require_relative 'commerce_store'

module CommerceCopilot
  M = Praxo::Models
  TENANT = 'acme'

  def self.store
    @store ||= CommerceStore.new
  end

  def self.reset_store!
    @store = CommerceStore.new
  end

  class ParameterizedTool < Praxo::Agent::FuncTool
    attr_reader :parameters, :risk

    def initialize(name, description, parameters, risk, function)
      super(name, description, function)
      @parameters = parameters
      @risk = risk
    end
  end

  class FixtureModel
    def initialize(mode)
      @mode = mode
    end

    def generate(request)
      tools = request.messages.select { |message| message.role == M::TOOL }
      return call('charge-1', 'charge_payment',
                  { 'order_id' => 'draft-1' }) if @mode == 'direct'
      return call('refund-1', 'refund_order',
                  { 'order_id' => 'draft-1' }) if @mode == 'refund'
      if @mode == 'weak'
        return call('draft-1', 'draft_order',
                    { 'items' => items, 'review_only' => false })
      end
      if tools.empty?
        call('search-1', 'search_catalog', { 'query' => 'plan' })
      elsif tools.length == 1
        call('quote-1', 'quote_cart', { 'items' => items })
      elsif tools.length == 2
        call('draft-1', 'draft_order', {
               'items' => items, 'review_only' => true,
               'diagnosis' => 'Two Starter plans fit the requested budget.',
               'rationale' => 'The cart is in stock and remains review-only.'
             })
      else
        M.response(message: M.message_assistant(
          'Draft prepared for review. No payment was charged.'
        ))
      end
    end

    private

    def items
      [{ 'sku' => 'sku-100', 'quantity' => 2 }]
    end

    def call(id, name, arguments)
      M.response(message: M.message_assistant('', [
        M.tool_call(id: id, name: name, arguments: arguments)
      ]))
    end
  end

  class RecordingSink
    attr_reader :types, :tools

    def initialize
      @types = []
      @tools = []
    end

    def emit(event)
      @types << event.type
      @tools << event.data['name'] if event.type == 'tool.call' && event.data
    end
  end

  Result = Struct.new(:status, :body, keyword_init: true)

  class AgentService
    def initialize(store: CommerceCopilot.store, live: false)
      @store = store
      @live = live
    end

    def run(tenant:, message:, mode: 'normal')
      return Result.new(status: 401, body: { 'error' => 'TENANT_REQUIRED' }) if tenant.to_s.empty?
      unless tenant == TENANT
        return Result.new(status: 403, body: { 'error' => 'TENANT_DENIED' })
      end

      state = { reads: 0, quotes: 0, drafts: 0, catalog: nil, quote: nil, draft: nil }
      sink = RecordingSink.new
      registry = Praxo::Agent::ToolRegistry.new
      register_tools(registry, state)
      model = @live ? live_model : FixtureModel.new(mode)
      options = Praxo::Agent::AgentOptions.new(model)
      options.tools = registry
      options.events = sink
      options.max_steps = 6
      options.allowed_tools = %w[search_catalog quote_cart draft_order
                                 charge_payment refund_order]
      options.require_policy = true
      options.require_tool_scope = true
      options.system_prompt =
        "You are a commerce back-office agent for tenant #{TENANT}. " \
        'Use search_catalog, quote_cart, and draft_order with review_only=true. ' \
        'Never charge or refund; return a concise draft summary.'
      options.policy = method(:policy)
      result = Praxo::Agent.run_agent(
        options, M.session(id: 'ai-commerce'), message.to_s
      )
      if state[:draft].nil?
        return Result.new(status: 500, body: { 'error' => 'DRAFT_MISSING' })
      end

      output = result.output.to_s
      interpretation = output.empty? ? 'Draft prepared for review.' : output[0, 1600]
      counts = @store.counts
      body = {
        'tenant' => tenant, 'model' => @live ? 'live' : 'deterministic',
        'catalog' => state[:catalog], 'quote' => state[:quote],
        'draft' => state[:draft], 'interpretation' => interpretation,
        'agent' => {
          'reads' => state[:reads], 'quotes' => state[:quotes],
          'drafts' => state[:drafts], 'tools' => sink.tools,
          'events' => sink.types, 'store' => counts
        },
        'payment_charges' => counts['charges'],
        'refunds' => counts['refunds'],
        'mutating_actions' => []
      }
      Result.new(status: 200, body: body)
    rescue Praxo::Error => error
      status = error.code == 'AGENT_POLICY_DENIED' ? 403 : 502
      Result.new(status: status, body: {
        'error' => error.code, 'message' => error.message,
        'payment_charges' => @store.counts['charges'],
        'refunds' => @store.counts['refunds'],
        'mutating_actions' => []
      })
    rescue StandardError => error
      Result.new(status: 500, body: {
        'error' => 'AGENT_ERROR', 'message' => error.message,
        'payment_charges' => @store.counts['charges'],
        'refunds' => @store.counts['refunds'],
        'mutating_actions' => []
      })
    end

    private

    def register_tools(registry, state)
      registry.register(ParameterizedTool.new(
        'search_catalog', 'Search the application-owned catalog.',
        {
          'type' => 'object',
          'properties' => { 'query' => { 'type' => 'string' } },
          'required' => ['query']
        }, 'read', lambda do |args|
          state[:reads] += 1
          state[:catalog] = ((state[:catalog] || []) + @store.search(args['query']))
                             .uniq { |item| item['sku'] }
          { 'source' => 'catalog_fixture', 'items' => state[:catalog] }
        end
      ))
      registry.register(ParameterizedTool.new(
        'quote_cart', 'Compute a cart total and stock status; no reservation.',
        {
          'type' => 'object',
          'properties' => {
            'items' => {
              'type' => 'array',
              'items' => {
                'type' => 'object',
                'properties' => {
                  'sku' => { 'type' => 'string' },
                  'quantity' => { 'type' => 'integer' }
                },
                'required' => %w[sku quantity]
              }
            }
          },
          'required' => ['items']
        }, 'read', lambda do |args|
          state[:quotes] += 1
          state[:quote] = @store.quote(args['items'])
          state[:quote]
        end
      ))
      registry.register(ParameterizedTool.new(
        'draft_order', 'Save a review-only order draft; never charges.',
        {
          'type' => 'object',
          'properties' => {
            'items' => { 'type' => 'array' },
            'review_only' => { 'type' => 'boolean' },
            'diagnosis' => { 'type' => 'string' },
            'rationale' => { 'type' => 'string' }
          },
          'required' => %w[items review_only diagnosis rationale]
        }, 'write', lambda do |args|
          state[:drafts] += 1
          state[:draft] = @store.draft_order(
            tenant: TENANT, items: args['items'],
            diagnosis: args['diagnosis'], rationale: args['rationale']
          )
        end
      ))
      registry.register(ParameterizedTool.new(
        'charge_payment', 'Would charge a payment; always denied.',
        { 'type' => 'object', 'properties' => { 'order_id' => { 'type' => 'string' } } },
        'write', lambda do |args|
          @store.record_charge(tenant: TENANT, order_id: args['order_id'])
        end
      ))
      registry.register(ParameterizedTool.new(
        'refund_order', 'Would refund an order; always denied.',
        { 'type' => 'object', 'properties' => { 'order_id' => { 'type' => 'string' } } },
        'write', lambda do |args|
          @store.record_refund(tenant: TENANT, order_id: args['order_id'])
        end
      ))
    end

    def policy(action)
      allowed = action.kind == 'model.generate'
      if action.kind == 'tool.invoke' && action.arguments.is_a?(Hash)
        case action.tool_name
        when 'search_catalog', 'quote_cart'
          allowed = true
        when 'draft_order'
          allowed = action.arguments['review_only'] == true &&
                    !action.arguments['diagnosis'].to_s.strip.empty? &&
                    !action.arguments['rationale'].to_s.strip.empty? &&
                    action.arguments['items'].is_a?(Array) &&
                    !action.arguments['items'].empty?
        end
      end
      M.decision(allowed: allowed, reason: 'tenant-scoped review-only commerce')
    end

    def live_model
      base_url = ENV.fetch('PRAXO_BASE_URL', 'http://localhost:11434/v1')
      model_name = ENV.fetch('PRAXO_MODEL', 'qwen3.5:4b')
      key = ENV['PRAXO_API_KEY']
      transport = lambda do |path, payload|
        curl_transport("#{base_url.sub(%r{/$}, '')}#{path}", payload, key)
      end
      Praxo::Adapters::OpenAICompatible.new(
        base_url: base_url, model: model_name, api_key: key, transport: transport
      )
    end

    def curl_transport(url, payload, key)
      curl = ENV.fetch('CURL', 'curl')
      args = [curl, '-sS', '-X', 'POST', '-H', 'Content-Type: application/json']
      args << '--ssl-no-revoke' if Gem.win_platform?
      args += ['-H', "Authorization: Bearer #{key}"] if key && !key.empty?
      args += ['--data-binary', JSON.generate(payload), '-w', "\n%{http_code}", url]
      stdout, stderr, status = Open3.capture3(*args)
      raise "provider request failed: #{stderr}" unless status.success?
      index = stdout.rindex("\n")
      response_body = index ? stdout[0...index] : stdout
      code = index ? stdout[(index + 1)..].to_s.strip.to_i : 0
      unless code.between?(200, 299)
        Praxo.error('PROVIDER_HTTP', "provider returned HTTP #{code}: #{response_body[0, 512]}")
      end
      JSON.parse(response_body)
    end
  end
end
