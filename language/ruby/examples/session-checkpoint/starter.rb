$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
require 'praxo'

module SessionCheckpointStarter
  M = Praxo::Models

  class TurnModel
    def generate(request)
      M.response(message: M.message_assistant("turn #{request.messages.length}"))
    end
  end

  def self.turn_model
    TurnModel.new
  end

  def self.message_from_wire(item)
    M.message(
      role: item['role'],
      content: item['content'],
      tool_id: item['toolId']
    )
  end

  def self.checkpoint_payload(allowlist, session)
    allowlist.marshal(
      'session',
      { 'messages' => session.messages.map { |message| M.message_wire(message) } }
    )
  end

  def self.run(out = $stdout)
    allowlist = Praxo::Runtime::CheckpointAllowlist.new
    allowlist.register('session')
    session = M.session(
      id: 'session-1',
      messages: [
        M.message(role: M::USER, content: 'first'),
        M.message(role: M::ASSISTANT, content: 'ack')
      ]
    )
    payload = checkpoint_payload(allowlist, session)

    stored = allowlist.unmarshal(payload)
    session.messages = stored['messages'].map { |item| message_from_wire(item) }
    result = Praxo::Agent.run_agent(
      Praxo::Agent::AgentOptions.new(turn_model),
      session,
      'second'
    )
    raise "unexpected second turn: #{result.output}" unless result.output == 'turn 3'

    session.messages << M.message(role: M::USER, content: 'second')
    session.messages << M.message(role: M::ASSISTANT, content: result.output)
    payload = checkpoint_payload(allowlist, session)

    stored = allowlist.unmarshal(payload)
    session.messages = stored['messages'].map { |item| message_from_wire(item) }
    result = Praxo::Agent.run_agent(
      Praxo::Agent::AgentOptions.new(turn_model),
      session,
      'third'
    )
    raise "unexpected third turn: #{result.output}" unless result.output == 'turn 5'

    out.puts "restored messages: #{session.messages.length}"
    out.puts "output: #{result.output}"
  end
end

SessionCheckpointStarter.run if $PROGRAM_NAME == __FILE__
