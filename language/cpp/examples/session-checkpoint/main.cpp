#include <iostream>
#include <memory>
#include <string>

#include "praxo/agent.hpp"
#include "praxo/models.hpp"
#include "praxo/runtime.hpp"

using namespace praxo;

namespace {

class TurnModel : public Model {
public:
    Response generate(const Request& request) override {
        Response response;
        response.message = assistant_message(
            "turn " + std::to_string(request.messages.size()));
        return response;
    }
};

Json session_payload(const Session& session) {
    Json messages = Json::array();
    for (const Message& message : session.messages) {
        messages.push_back(message_wire(message));
    }
    Json value = Json::object();
    value["messages"] = messages;
    return value;
}

void restore(Session& session, const Json& value) {
    session.messages.clear();
    for (const Json& item : value["messages"].as_array()) {
        Message message = text_message(
            item["role"].as_string(),
            item.contains("content") ? item["content"].as_string() : "");
        session.messages.push_back(message);
    }
}

}  // namespace

int main() {
    CheckpointAllowlist allowlist;
    allowlist.register_type("session");
    Session session{"session-1", {
        text_message("user", "first"),
        text_message("assistant", "ack"),
    }};
    std::string payload = allowlist.marshal("session", session_payload(session));
    restore(session, allowlist.unmarshal(payload));

    Agent agent(AgentOptions(std::make_shared<TurnModel>()));
    RunResult result = agent.run(session, "second");
    if (result.output != "turn 3") {
        std::cerr << "unexpected second turn: " << result.output << std::endl;
        return 1;
    }

    session.messages.push_back(text_message("user", "second"));
    session.messages.push_back(text_message("assistant", result.output));
    payload = allowlist.marshal("session", session_payload(session));
    restore(session, allowlist.unmarshal(payload));

    result = agent.run(session, "third");
    if (result.output != "turn 5") {
        std::cerr << "unexpected third turn: " << result.output << std::endl;
        return 1;
    }

    std::cout << "restored messages: " << session.messages.size() << std::endl;
    std::cout << "output: " << result.output << std::endl;
    return 0;
}
