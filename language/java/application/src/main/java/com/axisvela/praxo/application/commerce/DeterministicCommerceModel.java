package com.axisvela.praxo.application.commerce;

import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Request;
import com.axisvela.praxo.model.Response;
import com.axisvela.praxo.model.ToolCall;
import com.axisvela.praxo.util.Json;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

final class DeterministicCommerceModel implements Model {
    private final String intent;

    DeterministicCommerceModel(String intent) {
        this.intent = intent;
    }

    @Override
    public Response generate(Request request) {
        List<Message> toolMessages = request.messages().stream()
                .filter(message -> Message.TOOL.equals(message.role()))
                .toList();

        if (toolMessages.isEmpty()) {
            String lower = intent.toLowerCase(Locale.ROOT);
            if (lower.contains("checkout now") || lower.contains("buy now") || lower.contains("pay now")) {
                return Response.of(Message.assistant("", List.of(
                        new ToolCall("checkout-1", "checkout", Map.of("intent", intent)))));
            }
            return Response.of(Message.assistant("", List.of(
                    new ToolCall("search-1", "search_catalog", Map.of(
                            "query", intent,
                            "intent", intent)))));
        }

        if (toolMessages.size() == 1) {
            Map<String, Object> search = Json.object(toolMessages.get(0).content());
            List<Object> products = Json.asArray(search.get("products"));
            Map<String, Object> first = products.isEmpty() ? Map.of() : Json.asObject(products.get(0));
            String sku = Json.string(first.get("sku"));
            return Response.of(Message.assistant("", List.of(
                    new ToolCall("inventory-1", "check_inventory", Map.of(
                            "sku", sku == null ? "" : sku)))));
        }

        if (toolMessages.size() == 2) {
            Map<String, Object> inventory = Json.object(toolMessages.get(1).content());
            Map<String, Object> product = Json.asObject(inventory.get("product"));
            String sku = Json.string(product.get("sku"));
            return Response.of(Message.assistant("", List.of(
                    new ToolCall("cart-1", "draft_cart", Map.of(
                            "sku", sku == null ? "" : sku,
                            "quantity", 1,
                            "intent", intent,
                            "rationale",
                            "The first catalog match fits the trail-running intent and has inventory available."))));
        }

        if (toolMessages.size() == 3) {
            Map<String, Object> cart = Json.object(toolMessages.get(2).content());
            String cartId = Json.string(cart.get("cart_id"));
            return Response.of(Message.assistant("", List.of(
                    new ToolCall("review-1", "request_checkout_review", Map.of(
                            "cart_id", cartId == null ? "" : cartId,
                            "action", "checkout_review")))));
        }

        Map<String, Object> search = Json.object(toolMessages.get(0).content());
        Map<String, Object> inventory = Json.object(toolMessages.get(1).content());
        Map<String, Object> cart = Json.object(toolMessages.get(2).content());
        Map<String, Object> review = Json.object(toolMessages.get(3).content());

        Map<String, Object> report = new LinkedHashMap<>();
        report.put("intent", intent);
        report.put("products", search.get("products"));
        report.put("inventory", inventory);
        report.put("cart", cart);
        report.put("review", review);
        report.put("checkouts_executed", 0);
        return Response.of(Message.assistant(Json.stringify(report), List.of()));
    }
}
