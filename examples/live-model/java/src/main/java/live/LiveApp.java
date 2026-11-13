package live;

import com.axisvela.praxo.adapters.OpenAIConfig;
import com.axisvela.praxo.adapters.OpenAICompatibleModel;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;

import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class LiveApp {
    private LiveApp() {
    }

    static final class TimeTool implements Tool {
        @Override
        public String name() {
            return "get_time";
        }

        @Override
        public String description() {
            return "Return the current UTC time in ISO 8601 format.";
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            return Instant.now().toString();
        }
    }

    public static void main(String[] args) throws Exception {
        String baseUrl = envOr("PRAXO_BASE_URL", "http://localhost:11434/v1");
        String modelName = envOr("PRAXO_MODEL", "llama3.2");
        String prompt = envOr(
                "PRAXO_PROMPT",
                "What time is it? Use the get_time tool and reply with the time.");

        Registry tools = new Registry();
        tools.register(new TimeTool());

        AgentOptions options = new AgentOptions(new OpenAICompatibleModel(
                new OpenAIConfig(
                        baseUrl,
                        envOr("PRAXO_API_KEY", ""),
                        modelName,
                        120,
                        Map.of())));
        options.tools = tools;
        options.systemPrompt =
                "You are a concise assistant. Use the provided tools when they help.";
        options.maxSteps = 4;
        options.allowedTools = List.of("get_time");
        options.policy = (Action action) -> {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("model generation");
            }
            if ("tool.invoke".equals(action.kind())) {
                return "get_time".equals(action.toolName())
                        ? Decision.allow("get_time is permitted")
                        : Decision.deny("only get_time is permitted");
            }
            return Decision.deny("unsupported action");
        };

        try {
            var result = new Agent(options).run(new Session("live-model"), prompt);
            System.out.println(result.output);
        } catch (Exception error) {
            System.err.println(
                    "live model run failed: " + error.getMessage()
                            + "\n\nCheck PRAXO_BASE_URL (" + baseUrl
                            + "), PRAXO_MODEL (" + modelName + "), and PRAXO_API_KEY");
            throw error;
        }
    }

    private static String envOr(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isEmpty() ? fallback : value;
    }
}
