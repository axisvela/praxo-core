package structured;

import com.axisvela.praxo.adapters.OpenAIConfig;
import com.axisvela.praxo.adapters.OpenAICompatibleModel;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.middleware.StructuredOutput;
import com.axisvela.praxo.model.Model;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

public final class Summarize {
    private Summarize() {
    }

    static final Map<String, Object> SUMMARY_SCHEMA = Map.of(
            "type", "object",
            "required", List.of("title", "summary", "tags"),
            "properties", Map.of(
                    "title", Map.of("type", "string"),
                    "summary", Map.of("type", "string"),
                    "tags", Map.of(
                            "type", "array",
                            "items", Map.of("type", "string"))));

    public static String summarize(String text, Model model) throws Exception {
        Model selected = model == null
                ? new OpenAICompatibleModel(new OpenAIConfig(
                        envOr("PRAXO_BASE_URL", "http://localhost:11434/v1"),
                        envOr("PRAXO_API_KEY", ""),
                        envOr("PRAXO_MODEL", "llama3.2"),
                        60,
                        Map.of()))
                : model;

        AgentOptions options = new AgentOptions(selected);
        options.systemPrompt =
                "Summarize the supplied text as JSON with title, summary, and tags. "
                        + "Return only JSON.";
        options.structuredOutput = new StructuredOutput(
                SUMMARY_SCHEMA, "summary", StructuredOutput.AUTO, 0, null, null);
        return new Agent(options)
                .run(new Session("structured-output"), text)
                .output;
    }

    public static void main(String[] args) throws Exception {
        String text = String.join(" ", args).trim();
        if (text.isEmpty()) {
            text = new String(System.in.readAllBytes(), StandardCharsets.UTF_8).trim();
        }
        if (text.isEmpty()) {
            System.err.println("usage: summarize <text>");
            System.exit(2);
        }
        try {
            System.out.println(summarize(text, null));
        } catch (Exception error) {
            System.err.println(
                    "structured output run failed: " + error.getMessage()
                            + "\n\nCheck PRAXO_BASE_URL, PRAXO_MODEL, and PRAXO_API_KEY");
            throw error;
        }
    }

    private static String envOr(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isEmpty() ? fallback : value;
    }
}
