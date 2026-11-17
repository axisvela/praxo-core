#!/usr/bin/env ruby

require_relative '../../lib/praxo'

module AdvancedDelegationGovernance
  class BudgetExhausted < StandardError
  end

  class DelegationError < StandardError
  end

  class SharedBudget
    attr_reader :remaining

    def initialize(remaining)
      @remaining = remaining
    end

    def available?
      @remaining.positive?
    end

    def take
      return false unless @remaining.positive?

      @remaining -= 1
      true
    end
  end

  class ComposedPolicy
    def initialize(*hooks)
      @hooks = hooks.compact
    end

    def call(action)
      @hooks.each do |hook|
        decision = hook.call(action)
        return decision unless decision.allowed
      end
      Praxo::Models.decision(allowed: true, reason: 'delegation policy chain allowed')
    end
  end

  class BudgetedTool
    attr_reader :name, :description

    def initialize(inner, budget)
      @inner = inner
      @budget = budget
      @name = inner.name
      @description = inner.description
    end

    def parameters
      @inner.respond_to?(:parameters) ? @inner.parameters : nil
    end

    def risk
      @inner.respond_to?(:risk) ? @inner.risk : nil
    end

    def invoke(arguments)
      raise BudgetExhausted, 'delegation budget exhausted' unless @budget.take

      @inner.invoke(arguments)
    end
  end

  class ChildScope
    attr_reader :authority

    def initialize(authority, release)
      @authority = authority
      @release = release
    end

    def release
      @release.call
    end

    def run(model, tools, prompt, middleware: [], cancellation: nil)
      names = @authority[:allowed].sort
      scoped = Praxo::Agent::ToolRegistry.new
      names.each do |name|
        scoped.register(BudgetedTool.new(tools.get(name), @authority[:budget]))
      end
      options = Praxo::Agent::AgentOptions.new(model)
      options.tools = scoped
      options.max_steps = 3
      options.allowed_tools = names
      options.policy = @authority[:policy]
      options.middleware = middleware
      options.cancellation = cancellation
      options.require_policy = true
      options.require_tool_scope = true
      Praxo::Agent.run_agent(
        options,
        Praxo::Models.session(id: 'governed-delegation-child'),
        prompt
      )
    end
  end

  class Governor
    def initialize(authority)
      @authority = authority
      @active = 0
    end

    def delegate(allowed:, delegable: nil, policy: nil)
      allowed = Array(allowed)
      delegable = Array(delegable)
      if @authority[:depth] + 1 > @authority[:max_depth]
        raise DelegationError, 'delegation depth exceeded'
      end
      raise DelegationError, 'delegation tool scope is empty' if allowed.empty?

      allowed.each do |name|
        unless @authority[:delegable].include?(name) && @authority[:allowed].include?(name)
          raise DelegationError, 'delegation scope exceeds parent'
        end
      end
      delegable.each do |name|
        unless @authority[:delegable].include?(name)
          raise DelegationError, 'child delegable scope exceeds parent'
        end
      end
      unless @authority[:budget].available?
        raise BudgetExhausted, 'delegation budget exhausted'
      end
      if @active >= @authority[:max_children]
        raise DelegationError, 'delegation child limit exceeded'
      end

      @active += 1
      released = false
      release = lambda do
        next if released

        released = true
        @active -= 1
      end
      child_authority = {
        allowed: allowed,
        delegable: delegable,
        max_depth: @authority[:max_depth],
        max_children: @authority[:max_children],
        depth: @authority[:depth] + 1,
        budget: @authority[:budget],
        policy: ComposedPolicy.new(@authority[:policy], policy)
      }
      ChildScope.new(child_authority, release)
    end
  end

  class FixtureModel
    attr_reader :calls

    def initialize(tool_name, arguments, final, &on_generate)
      @tool_name = tool_name
      @arguments = arguments
      @final = final
      @on_generate = on_generate
      @calls = 0
    end

    def generate(request)
      @calls += 1
      @on_generate&.call
      last = request.messages.last
      if last.role == Praxo::Models::TOOL
        return Praxo::Models.response(message: Praxo::Models.message_assistant(@final))
      end

      Praxo::Models.response(message: Praxo::Models.message_assistant(
        '',
        [Praxo::Models.tool_call(id: 'call-1', name: @tool_name, arguments: @arguments)]
      ))
    end
  end

  class RecordTool
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def name
      'record'
    end

    def description
      'Record a delegated effect.'
    end

    def parameters
      {
        'type' => 'object',
        'required' => ['target'],
        'properties' => { 'target' => { 'type' => 'string' } }
      }
    end

    def risk
      'write'
    end

    def invoke(arguments)
      @calls += 1
      "recorded:#{arguments['target']}"
    end
  end

  class ParentOnlyTool
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def name
      'parent_only'
    end

    def description
      'A tool that must remain outside the child scope.'
    end

    def invoke(_arguments)
      @calls += 1
      'parent-effect'
    end
  end

  module_function

  def check(condition, message)
    raise message unless condition

    nil
  end

  def expect_error(klass, message)
    begin
      yield
    rescue klass => error
      return error
    end
    raise message
  end

  def allow_all(_action)
    Praxo::Models.decision(allowed: true, reason: 'root')
  end

  def record_policy(action)
    return Praxo::Models.decision(allowed: true, reason: 'non-tool action') \
      unless action.kind == 'tool.invoke'
    return Praxo::Models.decision(allowed: false, reason: 'child may only record') \
      unless action.tool_name == 'record'

    if action.arguments['target'] == 'blocked'
      return Praxo::Models.decision(allowed: false, reason: 'blocked target')
    end

    Praxo::Models.decision(allowed: true, reason: 'record allowed')
  end

  def authority(allowed, delegable, max_depth, max_children, depth: 0,
                budget: SharedBudget.new(1), policy: nil)
    {
      allowed: allowed,
      delegable: delegable,
      max_depth: max_depth,
      max_children: max_children,
      depth: depth,
      budget: budget,
      policy: policy
    }
  end
end

include AdvancedDelegationGovernance

passed = 0

record = RecordTool.new
parent_only = ParentOnlyTool.new
tools = Praxo::Agent::ToolRegistry.new
tools.register(record)
tools.register(parent_only)
root = Governor.new(authority(
  %w[record parent_only], %w[record], 1, 2,
  budget: SharedBudget.new(2), policy: method(:allow_all)
))
expect_error(DelegationError, 'scope escalation was not rejected') do
  root.delegate(allowed: ['parent_only'])
end
check(record.calls.zero? && parent_only.calls.zero?, 'scope escalation produced effects')
root.delegate(allowed: ['record'], policy: method(:record_policy)).release
passed += 1

depth_root = Governor.new(authority(
  %w[record], %w[record], 1, 1,
  budget: SharedBudget.new(2), policy: method(:allow_all)
))
depth_child = depth_root.delegate(allowed: ['record'], policy: method(:record_policy))
expect_error(DelegationError, 'grandchild depth was not rejected') do
  Governor.new(depth_child.authority).delegate(allowed: ['record'])
end
depth_child.release
passed += 1

child_limit = Governor.new(authority(
  %w[record], %w[record], 1, 1,
  budget: SharedBudget.new(2), policy: method(:allow_all)
))
first_child = child_limit.delegate(allowed: ['record'], policy: method(:record_policy))
expect_error(DelegationError, 'child count limit was not enforced') do
  child_limit.delegate(allowed: ['record'])
end
first_child.release
child_limit.delegate(allowed: ['record'], policy: method(:record_policy)).release
passed += 1

budget_record = RecordTool.new
budget_tools = Praxo::Agent::ToolRegistry.new
budget_tools.register(budget_record)
budget_root = Governor.new(authority(
  %w[record], %w[record], 1, 2,
  budget: SharedBudget.new(1), policy: method(:allow_all)
))
budget_first = budget_root.delegate(allowed: ['record'], policy: method(:record_policy))
budget_second = budget_root.delegate(allowed: ['record'], policy: method(:record_policy))
budget_first.run(
  FixtureModel.new('record', { 'target' => 'first' }, 'first-done'),
  budget_tools,
  'record once'
)
expect_error(BudgetExhausted, 'sibling budget was not shared') do
  budget_second.run(
    FixtureModel.new('record', { 'target' => 'second' }, 'second-done'),
    budget_tools,
    'record twice'
  )
end
check(budget_record.calls == 1, 'sibling budget effect count was not one')
budget_first.release
budget_second.release
passed += 1

cancel_record = RecordTool.new
cancel_tools = Praxo::Agent::ToolRegistry.new
cancel_tools.register(cancel_record)
cancel_root = Governor.new(authority(
  %w[record], %w[record], 1, 1,
  budget: SharedBudget.new(1), policy: method(:allow_all)
))
cancel_child = cancel_root.delegate(allowed: ['record'], policy: method(:record_policy))
cancelled = { value: false }
cancel_model = FixtureModel.new('record', { 'target' => 'safe' }, 'unexpected') do
  cancelled[:value] = true
end
cancel_error = expect_error(Praxo::Error, 'cancellation did not stop the child run') do
  cancel_child.run(
    cancel_model,
    cancel_tools,
    'cancel before effect',
    cancellation: -> { cancelled[:value] }
  )
end
check(cancel_error.code == 'AGENT_CANCELLED', 'cancellation code')
check(cancel_record.calls.zero?, 'cancellation produced an effect')
cancel_child.release
passed += 1

edit_record = RecordTool.new
edit_tools = Praxo::Agent::ToolRegistry.new
edit_tools.register(edit_record)
edit_root = Governor.new(authority(
  %w[record], %w[record], 1, 1,
  budget: SharedBudget.new(1), policy: method(:allow_all)
))
edit_child = edit_root.delegate(allowed: ['record'], policy: method(:record_policy))
edit_middleware = Object.new
def edit_middleware.before_tool(call)
  call.arguments = { 'target' => 'blocked' }
  call
end
edit_error = expect_error(Praxo::Error, 'final argument reauthorization did not fail') do
  edit_child.run(
    FixtureModel.new('record', { 'target' => 'safe' }, 'unexpected'),
    edit_tools,
    'record safely',
    middleware: [edit_middleware]
  )
end
check(edit_error.code == 'AGENT_POLICY_DENIED', 'final argument policy code')
check(edit_record.calls.zero?, 'final argument produced an effect')
edit_child.release
passed += 1

puts "Ruby governance delegation checks passed (#{passed})"
