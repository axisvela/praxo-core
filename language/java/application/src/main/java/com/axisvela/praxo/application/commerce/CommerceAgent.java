package com.axisvela.praxo.application.commerce;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.adapters.OpenAICompatibleModel;
import com.axisvela.praxo.adapters.OpenAIConfig;
import com.axisvela.praxo.agent.Agent;
import com.axisvela.praxo.agent.AgentOptions;
import com.axisvela.praxo.agent.Session;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.ToolSpec;
import com.axisvela.praxo.tool.Registry;
import com.axisvela.praxo.tool.Tool;
import com.axisvela.praxo.util.Json;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public final class CommerceAgent {
    private final CatalogService catalog;
    private final DraftService drafts;
    private final CommerceSettings settings;
    private final Model modelOverride;

    @Autowired
    public CommerceAgent(
            CatalogService catalog,
            DraftService drafts,
            CommerceSettings settings) {
        this(catalog, drafts, settings, null);
    }

    public CommerceAgent(
            CatalogService catalog,
            DraftService drafts,
            CommerceSettings settings,
            Model modelOverride) {
        this.catalog = catalog;
        this.drafts = drafts;
        this.settings = settings;
        this.modelOverride = modelOverride;
    }

    public ReviewResult review(String tenantId, String intent) {
        int[] reads = {0};
        int[] draftsCreated = {0};
        int[] reviewsCreated = {0};
        int[] checkouts = {0};

        Registry registry = new Registry();
        registry.register(new Tool() {
            public String name() {
                return "search_catalog";
            }

            public String description() {
                return "Search the application-owned commerce catalog; read-only.";
            }

            public ToolSpec spec() {
                return new ToolSpec(name(), description(), Map.of(
                        "type", "object",
                        "required", List.of("query", "intent"),
                        "properties", Map.of(
                                "query", Map.of("type", "string"),
                                "intent", Map.of("type", "string"))), "read");
            }

            public Object invoke(Map<String, Object> args) {
                reads[0]++;
                String query = args.get("query") instanceof String text ? text : "";
                return Map.of("products", catalog.search(query));
            }
        });
        registry.register(new Tool() {
            public String name() {
                return "check_inventory";
            }

            public String description() {
                return "Read inventory and price for one SKU; read-only.";
            }

            public ToolSpec spec() {
                return new ToolSpec(name(), description(), Map.of(
                        "type", "object",
                        "required", List.of("sku"),
                        "properties", Map.of("sku", Map.of("type", "string"))), "read");
            }

            public Object invoke(Map<String, Object> args) {
                reads[0]++;
                return catalog.inventory((String) args.get("sku"));
            }
        });
        registry.register(new Tool() {
            public String name() {
                return "draft_cart";
            }

            public String description() {
                return "Create a review-only cart draft; never check out or charge.";
            }

            public ToolSpec spec() {
                return new ToolSpec(name(), description(), Map.of(
                        "type", "object",
                        "required", List.of("sku", "quantity", "intent", "rationale"),
                        "properties", Map.of(
                                "sku", Map.of("type", "string"),
                                "quantity", Map.of("type", "integer"),
                                "intent", Map.of("type", "string"),
                                "rationale", Map.of("type", "string"))), "write");
            }

            public Object invoke(Map<String, Object> args) {
                draftsCreated[0]++;
                String sku = (String) args.get("sku");
                int quantity = args.get("quantity") instanceof Number number
                        ? number.intValue() : 0;
                String rationale = (String) args.get("rationale");
                return drafts.draftCart(sku, quantity, catalog.product(sku), rationale);
            }
        });
        registry.register(new Tool() {
            public String name() {
                return "request_checkout_review";
            }

            public String description() {
                return "Create a review-only checkout request; never pays or ships.";
            }

            public ToolSpec spec() {
                return new ToolSpec(name(), description(), Map.of(
                        "type", "object",
                        "required", List.of("cart_id", "action"),
                        "properties", Map.of(
                                "cart_id", Map.of("type", "string"),
                                "action", Map.of(
                                        "type", "string",
                                        "enum", List.of("checkout_review")))), "write");
            }

            public Object invoke(Map<String, Object> args) {
                reviewsCreated[0]++;
                return drafts.requestCheckoutReview((String) args.get("cart_id"));
            }
        });
        registry.register(new Tool() {
            public String name() {
                return "checkout";
            }

            public String description() {
                return "Would charge and place the order. Always denied in the agent path.";
            }

            public ToolSpec spec() {
                return new ToolSpec(name(), description(), Map.of(
                        "type", "object",
                        "required", List.of("intent"),
                        "properties", Map.of("intent", Map.of("type", "string"))), "write");
            }

            public Object invoke(Map<String, Object> args) {
                checkouts[0]++;
                return drafts.checkout("cart-1");
            }
        });

        Model baseModel;
        String modelMode;
        if (modelOverride != null) {
            baseModel = modelOverride;
            modelMode = "injected";
        } else if (settings.baseUrl() != null
                && !settings.baseUrl().isBlank()
                && settings.model() != null
                && !settings.model().isBlank()) {
            baseModel = new OpenAICompatibleModel(new OpenAIConfig(
                    settings.baseUrl(),
                    settings.apiKey(),
                    settings.model(),
                    60,
                    Map.of()));
            modelMode = "live";
        } else {
            baseModel = new DeterministicCommerceModel(intent);
            modelMode = "deterministic";
        }

        TracingModel tracing = new TracingModel(baseModel);
        AgentOptions options = new AgentOptions(tracing);
        options.tools = registry;
        options.allowedTools = List.of(
                "search_catalog",
                "check_inventory",
                "draft_cart",
                "request_checkout_review",
                "checkout");
        options.policy = new CommercePolicy(
                tenantId,
                settings.tenant(),
                settings.maxIntentLength());
        options.requirePolicy = true;
        options.requireToolScope = true;
        options.maxSteps = 6;
        options.maxTokens = 3000;
        options.modelCallLimit = 6;
        options.toolCallLimit = 6;
        options.systemPrompt = "You are an AI commerce assistant for tenant " + tenantId + ". "
                + "Use search_catalog, check_inventory, draft_cart, and request_checkout_review. "
                + "Draft only; never checkout, charge, or place an order. "
                + "Return JSON with intent, products, inventory, cart, review, and checkouts_executed.";

        try {
            var result = new Agent(options).run(
                    new Session("java-ai-commerce-" + tenantId + "-"
                            + Integer.toHexString(intent.hashCode())),
                    intent);
            Map<String, Object> report = parseReport(result.output);
            if (report == null) {
                throw new ReviewFailure(
                        "AGENT_INVALID_OUTPUT",
                        "agent did not return the required commerce package",
                        reads[0], draftsCreated[0], reviewsCreated[0], checkouts[0]);
            }
            if (!report.containsKey("intent")
                    || !report.containsKey("products")
                    || !report.containsKey("inventory")
                    || !report.containsKey("cart")
                    || !report.containsKey("review")
                    || !report.containsKey("checkouts_executed")
                    || Json.intValue(report.get("checkouts_executed")) != 0) {
                throw new ReviewFailure(
                        "AGENT_INVALID_OUTPUT",
                        "agent did not return the required commerce package",
                        reads[0], draftsCreated[0], reviewsCreated[0], checkouts[0]);
            }
            report.put("tenant", tenantId);
            report.put("model", modelMode);
            report.put("agent_trace", tracing.steps());
            return new ReviewResult(
                    report,
                    reads[0],
                    draftsCreated[0],
                    reviewsCreated[0],
                    checkouts[0]);
        } catch (PraxoException error) {
            throw new ReviewFailure(
                    error.code,
                    error.getMessage(),
                    reads[0], draftsCreated[0], reviewsCreated[0], checkouts[0]);
        } catch (ReviewFailure error) {
            throw error;
        } catch (Exception error) {
            throw new ReviewFailure(
                    "AGENT_RUNTIME_ERROR",
                    error.getMessage(),
                    reads[0], draftsCreated[0], reviewsCreated[0], checkouts[0]);
        }
    }

    private static Map<String, Object> parseReport(String output) {
        try {
            return Json.object(output);
        } catch (RuntimeException ignored) {
            java.util.regex.Matcher matcher = java.util.regex.Pattern
                    .compile("\\{.*\\}", java.util.regex.Pattern.DOTALL)
                    .matcher(output == null ? "" : output);
            if (matcher.find()) {
                try {
                    return Json.object(matcher.group());
                } catch (RuntimeException ignoredAgain) {
                    return null;
                }
            }
            return null;
        }
    }
}
