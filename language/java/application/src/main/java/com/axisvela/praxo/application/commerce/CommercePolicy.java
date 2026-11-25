package com.axisvela.praxo.application.commerce;

import com.axisvela.praxo.policy.Action;
import com.axisvela.praxo.policy.Decision;
import com.axisvela.praxo.policy.Hook;

import java.util.Map;

public final class CommercePolicy implements Hook {
    private final String tenantId;
    private final String expectedTenant;
    private final int maxIntentLength;

    public CommercePolicy(String tenantId, String expectedTenant, int maxIntentLength) {
        this.tenantId = tenantId;
        this.expectedTenant = expectedTenant;
        this.maxIntentLength = maxIntentLength;
    }

    @Override
    public Decision authorize(Action action) {
        if (!tenantId.equals(expectedTenant)) {
            return Decision.deny("tenant mismatch");
        }
        if ("model.generate".equals(action.kind())) {
            return Decision.allow("commerce generation");
        }
        if (!"tool.invoke".equals(action.kind())) {
            return Decision.deny("unsupported action");
        }

        Map<String, Object> arguments = action.arguments() == null ? Map.of() : action.arguments();
        if ("checkout".equals(action.toolName())) {
            return Decision.deny("checkout requires a separately approved host workflow");
        }

        String intent = stringValue(arguments.get("intent"));
        if (("search_catalog".equals(action.toolName()) || "draft_cart".equals(action.toolName()))
                && (intent == null || intent.isBlank() || intent.length() > maxIntentLength)) {
            return Decision.deny("intent is required");
        }

        return switch (action.toolName()) {
            case "search_catalog" -> Decision.allow("read-only catalog search");
            case "check_inventory" -> stringValue(arguments.get("sku")) != null
                    ? Decision.allow("inventory read")
                    : Decision.deny("sku is required");
            case "draft_cart" -> stringValue(arguments.get("sku")) != null
                    && intValue(arguments.get("quantity")) > 0
                    && stringValue(arguments.get("rationale")) != null
                    && !stringValue(arguments.get("rationale")).isBlank()
                    ? Decision.allow("draft cart with rationale")
                    : Decision.deny("sku, quantity, and rationale are required");
            case "request_checkout_review" -> "checkout_review".equals(arguments.get("action"))
                    ? Decision.allow("review-only checkout request")
                    : Decision.deny("only checkout_review is allowed");
            default -> Decision.deny("unsupported tool");
        };
    }

    private static String stringValue(Object value) {
        return value instanceof String text ? text : null;
    }

    private static int intValue(Object value) {
        return value instanceof Number number ? number.intValue() : 0;
    }
}
