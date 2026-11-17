package advanceddelegation;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.CancellationToken;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.middleware.Middleware;
import com.axisvela.praxo.middleware.MiddlewareToolCall;
import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.policy.Hook;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;

import java.io.PrintStream;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

final class GovernanceSelfTest {
    private GovernanceSelfTest() {
    }

    static final class BudgetExhausted extends RuntimeException {
        BudgetExhausted() {
            super("delegation budget exhausted");
        }
    }

    static final class DelegationException extends RuntimeException {
        DelegationException(String message) {
            super(message);
        }
    }

    static final class SharedBudget {
        private final AtomicInteger remaining;

        SharedBudget(int remaining) {
            this.remaining = new AtomicInteger(remaining);
        }

        boolean available() {
            return remaining.get() > 0;
        }

        boolean take() {
            return remaining.getAndUpdate(value -> value > 0 ? value - 1 : 0) > 0;
        }
    }

    static final class Authority {
        Set<String> allowed;
        Set<String> delegable;
        int maxDepth;
        int maxChildren;
        int depth;
        SharedBudget budget;
        Hook policy;

        Authority(
                Set<String> allowed,
                Set<String> delegable,
                int maxDepth,
                int maxChildren,
                int depth,
                SharedBudget budget,
                Hook policy) {
            this.allowed = allowed;
            this.delegable = delegable;
            this.maxDepth = maxDepth;
            this.maxChildren = maxChildren;
            this.depth = depth;
            this.budget = budget;
            this.policy = policy;
        }
    }

    static final class ChildScope {
        final Authority authority;
        private final Runnable release;

        ChildScope(Authority authority, Runnable release) {
            this.authority = authority;
            this.release = release;
        }

        void release() {
            release.run();
        }

        Object run(
                com.axisvela.praxo.model.Model model,
                Registry tools,
                String prompt,
                CancellationToken token,
                List<Middleware> middleware) throws Exception {
            Registry scoped = new Registry();
            for (String name : authority.allowed) {
                scoped.register(new BudgetedTool(tools.get(name), authority.budget));
            }
            AgentOptions options = new AgentOptions(model);
            options.tools = scoped;
            options.maxSteps = 3;
            options.allowedTools = List.copyOf(authority.allowed);
            options.policy = authority.policy;
            options.middleware = List.copyOf(middleware);
            options.cancellation = token;
            return new Agent(options).run(
                    new Session("governed-delegation-child"), prompt);
        }
    }

    static final class Governor {
        final Authority authority;
        private int active;

        Governor(Authority authority) {
            this.authority = authority;
        }

        synchronized ChildScope delegate(
                Set<String> allowed,
                Set<String> delegable,
                Hook policy) {
            int depth = authority.depth + 1;
            if (depth > authority.maxDepth) {
                throw new DelegationException("delegation depth exceeded");
            }
            if (allowed.isEmpty()) {
                throw new DelegationException("delegation tool scope is empty");
            }
            if (!authority.delegable.containsAll(allowed)) {
                throw new DelegationException("delegation scope exceeds parent");
            }
            if (!authority.allowed.containsAll(allowed)) {
                throw new DelegationException("delegation scope is not allowed");
            }
            if (!authority.delegable.containsAll(delegable)) {
                throw new DelegationException("child delegable scope exceeds parent");
            }
            if (!authority.budget.available()) {
                throw new BudgetExhausted();
            }
            if (active >= authority.maxChildren) {
                throw new DelegationException("delegation child limit exceeded");
            }
            active += 1;
            AtomicInteger released = new AtomicInteger();
            Runnable release = () -> {
                if (released.getAndIncrement() == 0) {
                    synchronized (Governor.this) {
                        active -= 1;
                    }
                }
            };
            return new ChildScope(
                    new Authority(
                            Set.copyOf(allowed),
                            Set.copyOf(delegable),
                            authority.maxDepth,
                            authority.maxChildren,
                            depth,
                            authority.budget,
                            compose(authority.policy, policy)),
                    release);
        }
    }

    static final class BudgetedTool implements Tool {
        private final Tool inner;
        private final SharedBudget budget;

        BudgetedTool(Tool inner, SharedBudget budget) {
            this.inner = inner;
            this.budget = budget;
        }

        @Override
        public String name() {
            return inner.name();
        }

        @Override
        public String description() {
            return inner.description();
        }

        @Override
        public Object invoke(Map<String, Object> args) throws Exception {
            if (!budget.take()) {
                throw new BudgetExhausted();
            }
            return inner.invoke(args);
        }
    }

    static Hook compose(Hook parent, Hook child) {
        return action -> {
            if (parent != null) {
                Decision decision = parent.authorize(action);
                if (!decision.allowed()) {
                    return decision;
                }
            }
            if (child != null) {
                return child.authorize(action);
            }
            return Decision.allow("delegation policy chain allowed");
        };
    }

    static Decision recordPolicy(Action action) {
        if (!"tool.invoke".equals(action.kind())) {
            return Decision.allow("non-tool action");
        }
        if (!"record".equals(action.toolName())) {
            return Decision.deny("child may only record");
        }
        Object target = action.arguments() == null
                ? null
                : action.arguments().get("target");
        if ("blocked".equals(target)) {
            return Decision.deny("blocked target");
        }
        return Decision.allow("record allowed");
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            throw new IllegalStateException(message);
        }
    }

    private static Map<String, Object> mutableArgs(String target) {
        return new LinkedHashMap<>(Map.of("target", target));
    }

    static void run(PrintStream out) throws Exception {
        App.RecordTool record = new App.RecordTool();
        Registry tools = new Registry();
        tools.register(record);
        Governor root = new Governor(new Authority(
                Set.of("record", "parent_only"),
                Set.of("record"),
                1,
                2,
                0,
                new SharedBudget(2),
                action -> Decision.allow("root")));

        try {
            root.delegate(Set.of("parent_only"), Set.of(), null);
            throw new IllegalStateException("child escaped the delegable scope");
        } catch (DelegationException expected) {
            check(record.calls() == 0, "scope rejection produced an effect");
        }

        ChildScope child = root.delegate(
                Set.of("record"), Set.of(), GovernanceSelfTest::recordPolicy);
        child.release();

        Governor depthRoot = new Governor(new Authority(
                Set.of("record"),
                Set.of("record"),
                1,
                1,
                0,
                new SharedBudget(2),
                action -> Decision.allow("root")));
        ChildScope depthChild = depthRoot.delegate(
                Set.of("record"), Set.of(), GovernanceSelfTest::recordPolicy);
        depthChild.authority.delegable = Set.of("record");
        try {
            new Governor(depthChild.authority)
                    .delegate(Set.of("record"), Set.of(), null);
            throw new IllegalStateException("delegation exceeded the depth limit");
        } catch (DelegationException expected) {
            depthChild.release();
        }

        Governor childLimit = new Governor(new Authority(
                Set.of("record"),
                Set.of("record"),
                1,
                1,
                0,
                new SharedBudget(2),
                action -> Decision.allow("root")));
        ChildScope firstChild = childLimit.delegate(
                Set.of("record"), Set.of(), GovernanceSelfTest::recordPolicy);
        try {
            childLimit.delegate(Set.of("record"), Set.of(), null);
            throw new IllegalStateException("delegation exceeded the child limit");
        } catch (DelegationException expected) {
            firstChild.release();
        }
        ChildScope secondChild = childLimit.delegate(Set.of("record"), Set.of(), null);
        secondChild.release();

        App.RecordTool budgetRecord = new App.RecordTool();
        Registry budgetTools = new Registry();
        budgetTools.register(budgetRecord);
        Governor budgetRoot = new Governor(new Authority(
                Set.of("record"),
                Set.of("record"),
                1,
                2,
                0,
                new SharedBudget(1),
                action -> Decision.allow("root")));
        ChildScope first = budgetRoot.delegate(
                Set.of("record"), Set.of(), GovernanceSelfTest::recordPolicy);
        ChildScope second = budgetRoot.delegate(
                Set.of("record"), Set.of(), GovernanceSelfTest::recordPolicy);
        first.run(
                new App.FixtureModel("record", mutableArgs("first"), "first-done"),
                budgetTools,
                "record once",
                null,
                List.of());
        try {
            second.run(
                    new App.FixtureModel("record", mutableArgs("second"), "second-done"),
                    budgetTools,
                    "record twice",
                    null,
                    List.of());
            throw new IllegalStateException("sibling budget was not enforced");
        } catch (BudgetExhausted expected) {
            check(budgetRecord.calls() == 1, "sibling budget produced extra effects");
        } finally {
            first.release();
            second.release();
        }

        App.RecordTool cancelRecord = new App.RecordTool();
        Registry cancelTools = new Registry();
        cancelTools.register(cancelRecord);
        Governor cancelRoot = new Governor(new Authority(
                Set.of("record"),
                Set.of("record"),
                1,
                1,
                0,
                new SharedBudget(1),
                action -> Decision.allow("root")));
        ChildScope canceled = cancelRoot.delegate(
                Set.of("record"), Set.of(), GovernanceSelfTest::recordPolicy);
        CancellationToken token = new CancellationToken();
        token.cancel();
        try {
            canceled.run(
                    new App.FixtureModel("record", mutableArgs("safe"), "unexpected"),
                    cancelTools,
                    "record after cancel",
                    token,
                    List.of());
            throw new IllegalStateException("canceled child reported success");
        } catch (PraxoException error) {
            check("AGENT_ABORTED".equals(error.code),
                    "unexpected cancellation error: " + error.code);
            check(cancelRecord.calls() == 0, "canceled child produced an effect");
        } finally {
            canceled.release();
        }

        App.RecordTool editRecord = new App.RecordTool();
        Registry editTools = new Registry();
        editTools.register(editRecord);
        Governor editRoot = new Governor(new Authority(
                Set.of("record"),
                Set.of("record"),
                1,
                1,
                0,
                new SharedBudget(1),
                action -> Decision.allow("root")));
        ChildScope edited = editRoot.delegate(
                Set.of("record"), Set.of(), GovernanceSelfTest::recordPolicy);
        Middleware edit = new Middleware() {
            @Override
            public void beforeTool(MiddlewareToolCall call) {
                call.call.arguments().put("target", "blocked");
            }
        };
        try {
            edited.run(
                    new App.FixtureModel("record", mutableArgs("safe"), "unexpected"),
                    editTools,
                    "record safely",
                    null,
                    List.of(edit));
            throw new IllegalStateException("edited child arguments were not reauthorized");
        } catch (PraxoException error) {
            check("AGENT_POLICY_DENIED".equals(error.code),
                    "unexpected policy error: " + error.code);
            check(editRecord.calls() == 0, "edited child arguments produced an effect");
        } finally {
            edited.release();
        }

        out.println("governance: delegation checks passed (6)");
    }
}
