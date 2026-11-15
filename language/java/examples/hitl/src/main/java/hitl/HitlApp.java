package hitl;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Result;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.hitl.InterruptAction;
import com.axisvela.praxo.hitl.InterruptDecision;
import com.axisvela.praxo.hitl.InterruptHandler;
import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public final class HitlApp {
    private HitlApp() {
    }

    static final class ScriptModel implements Model {
        private int calls;

        @Override
        public Response generate(Request request) {
            calls += 1;
            if (calls == 1) {
                return Response.of(Message.assistant("", List.of(
                        new ToolCall("write-1", "write_note",
                                Map.of("text", "hello", "visibility", "public")))));
            }
            return Response.of(Message.assistant("done", List.of()));
        }
    }

    static final class WriteNoteTool implements Tool {
        final List<String> notes = new ArrayList<>();

        @Override
        public String name() {
            return "write_note";
        }

        @Override
        public String description() {
            return "Write a short note with the requested visibility.";
        }

        @Override
        public Object invoke(Map<String, Object> args) {
            notes.add(String.valueOf(args.get("text")));
            return "written";
        }
    }

    static AgentOptions options(WriteNoteTool tool, InterruptHandler handler) {
        Registry registry = new Registry();
        registry.register(tool);
        AgentOptions options = new AgentOptions(new ScriptModel());
        options.tools = registry;
        options.maxSteps = 3;
        options.allowedTools = List.of("write_note");
        options.interruptOn.add("write_note");
        options.onInterruptDecision = handler;
        options.policy = (Action action) -> {
            if ("model.generate".equals(action.kind())) {
                return Decision.allow("model generation");
            }
            if ("tool.invoke".equals(action.kind())) {
                Object visibility = action.arguments() == null
                        ? null
                        : action.arguments().get("visibility");
                return "write_note".equals(action.toolName())
                        && "public".equals(visibility)
                        ? Decision.allow("public note")
                        : Decision.deny("only public notes are permitted");
            }
            return Decision.deny("unsupported action");
        };
        return options;
    }

    public static void main(String[] args) throws Exception {
        WriteNoteTool approvedTool = new WriteNoteTool();
        Result approved = new Agent(options(approvedTool,
                interrupt -> new InterruptDecision(
                        InterruptAction.APPROVE, null, "", "")))
                .run(new Session("hitl-approve"), "Write a note.");
        if (!"done".equals(approved.output) || approvedTool.notes.size() != 1) {
            throw new IllegalStateException(
                    "approve scenario failed: output=" + approved.output
                            + " effects=" + approvedTool.notes.size());
        }
        System.out.println("approve: written; effects=1");

        WriteNoteTool editedTool = new WriteNoteTool();
        try {
            new Agent(options(editedTool,
                    interrupt -> new InterruptDecision(
                            InterruptAction.EDIT,
                            Map.of("text", "hello", "visibility", "private"),
                            "",
                            "")))
                    .run(new Session("hitl-edit"), "Write a note.");
        } catch (PraxoException error) {
            if (!"AGENT_POLICY_DENIED".equals(error.code)
                    || !editedTool.notes.isEmpty()) {
                throw error;
            }
            System.out.println("edit: policy rejected; effects=0");
            return;
        }
        throw new IllegalStateException("edited private note was not denied");
    }
}
