import std.conv : to;
import std.stdio;
import praxo.agent;
import praxo.json;
import praxo.models;
import praxo.runtime;

class TurnModel : Model {
    Response generate(Request request) {
        return Response(Message.assistant("turn " ~ to!string(request.messages.length)), Usage());
    }
}

void main() {
    auto session = Session("session-1", [
        Message.text(USER, "first"),
        Message.text(ASSISTANT, "ack"),
    ]);
    auto options = new AgentOptions(new TurnModel());
    options.maxSteps = 2;
    auto agent = new Agent(options);

    auto result = agent.run(session, "second");
    assert(result.output == "turn 3");
    session.messages ~= Message.text(USER, "second");
    session.messages ~= Message.assistant(result.output);

    auto allow = new CheckpointAllowlist();
    allow.register("session");
    JSONValue[] items;
    foreach (message; session.messages) {
        JSONValue[string] object;
        object["role"] = JSONValue(message.role);
        object["content"] = JSONValue(message.content);
        items ~= JSONValue(object);
    }
    JSONValue[string] payload;
    payload["messages"] = JSONValue(items);
    auto data = allow.marshal("session", JSONValue(payload));
    auto decoded = allow.unmarshal(data);

    session.messages = null;
    foreach (item; getArray(decoded, "messages")) {
        session.messages ~= Message(getString(item, "role"), getString(item, "content"));
    }

    result = agent.run(session, "third");
    assert(result.output == "turn 5");
    writeln("restored messages: ", session.messages.length);
    writeln("output: ", result.output);
}
