package com.axisvela.praxo.agent;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.policy.Decision;

import java.util.List;

public final class AgentSafeDefaultsSelfTest {
    private AgentSafeDefaultsSelfTest() {
    }

    public static void main(String[] args) throws Exception {
        Model model = request -> Response.of(Message.assistant("ok", List.of()));

        AgentOptions missingPolicy = new AgentOptions(model);
        missingPolicy.requirePolicy = true;
        expectInvalid(missingPolicy, "require policy");

        AgentOptions missingScope = new AgentOptions(model);
        missingScope.requireToolScope = true;
        expectInvalid(missingScope, "require tool scope");

        AgentOptions allowed = new AgentOptions(model);
        allowed.requirePolicy = true;
        allowed.requireToolScope = true;
        allowed.allowedTools = List.of("echo");
        allowed.policy = action -> Decision.allow("ok");
        new Agent(allowed);

        System.out.println("agent safe defaults ok");
    }

    private static void expectInvalid(AgentOptions options, String message) {
        try {
            new Agent(options);
        } catch (PraxoException error) {
            if ("AGENT_INVALID_OPTIONS".equals(error.code)
                    && error.getMessage().contains(message)) {
                return;
            }
            throw error;
        }
        throw new AssertionError("expected " + message);
    }
}
