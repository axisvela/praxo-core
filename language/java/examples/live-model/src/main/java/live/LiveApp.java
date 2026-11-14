package live;

import com.axisvela.praxo.adapters.OpenAIConfig;
import com.axisvela.praxo.adapters.OpenAICompatibleModel;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.model.ToolSpec;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.policy.Hook;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;

public final class LiveApp {
    private LiveApp() {
    }

    static final class GetTimeTool implements Tool {
        @Override
        public String name() {
            return "get_time";
        }

        @Override
        public String description() {
            return "Return the current time in ISO 8601 format for the requested zone.";
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            ZoneId zone = "local".equals(args.get("zone"))
                    ? ZoneId.systemDefault()
                    : ZoneId.of("UTC");
            return Instant.now().atZone(zone).format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);
        }

        public ToolSpec spec() {
            return new ToolSpec(
                    name(),
                    description(),
                    Map.of(
                            "type", "object",
                            "properties", Map.of(
                                    "zone", Map.of(
                                            "type", "string",
                                            "enum", List.of("utc", "local"),
                                            "description", "utc or local; defaults to utc"))),
                    "read");
        }
    }

    static final class AllowGetTime implements Hook {
        @Override
        public Decision authorize(Action action) {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("model generation");
            }
            if ("tool.invoke".equals(action.kind())) {
                return "get_time".equals(action.toolName())
                        ? Decision.allow("get_time is permitted")
                        : Decision.deny("only get_time is permitted");
            }
            return Decision.deny("unsupported action");
        }
    }

    private static String envOr(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isEmpty() ? fallback : value;
    }

    public static void main(String[] args) {
        String baseUrl = envOr("PRAXO_BASE_URL", "http://localhost:11434/v1");
        String modelName = envOr("PRAXO_MODEL", "qwen3.5:4b");
        String prompt = envOr(
                "PRAXO_PROMPT",
                "What time is it? Use get_time with zone set to utc and reply with the time.");

        OpenAICompatibleModel model = new OpenAICompatibleModel(
                new OpenAIConfig(
                        baseUrl,
                        envOr("PRAXO_API_KEY", ""),
                        modelName,
                        120,
                        Map.of()));

        Registry tools = new Registry();
        tools.register(new GetTimeTool());

        AgentOptions options = new AgentOptions(model);
        options.tools = tools;
        options.systemPrompt =
                "You are a concise assistant. Use the provided tools when they help.";
        options.maxSteps = 4;
        options.allowedTools = List.of("get_time");
        options.policy = new AllowGetTime();

        try {
            var result = new Agent(options).run(new Session("live-model"), prompt);
            System.out.println(result.output);
        } catch (Exception error) {
            System.err.println(
                    "live model run failed: " + error.getMessage() + "\n\n"
                            + "Check PRAXO_BASE_URL (" + baseUrl + "), PRAXO_MODEL ("
                            + modelName + "), and PRAXO_API_KEY");
            System.exit(1);
        }
    }
}
