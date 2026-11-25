package com.axisvela.praxo.application.commerce;

import com.axisvela.praxo.PraxoException;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Service
public final class DraftService {
    private final Map<String, Map<String, Object>> carts = new ConcurrentHashMap<>();
    private final Map<String, Map<String, Object>> reviews = new ConcurrentHashMap<>();
    private final AtomicInteger cartSequence = new AtomicInteger();
    private final AtomicInteger reviewSequence = new AtomicInteger();
    private final AtomicInteger checkouts = new AtomicInteger();

    public Map<String, Object> draftCart(
            String sku,
            int quantity,
            Map<String, Object> product,
            String rationale) {
        String id = "cart-" + cartSequence.incrementAndGet();
        double price = ((Number) product.get("price")).doubleValue();
        Map<String, Object> cart = new LinkedHashMap<>();
        cart.put("cart_id", id);
        cart.put("sku", sku);
        cart.put("quantity", quantity);
        cart.put("subtotal", price * quantity);
        cart.put("currency", product.get("currency"));
        cart.put("rationale", rationale);
        cart.put("status", "draft_only");
        cart.put("review_required", true);
        cart.put("checkouts_executed", 0);
        carts.put(id, cart);
        return cart;
    }

    public Map<String, Object> requestCheckoutReview(String cartId) {
        if (!carts.containsKey(cartId)) {
            throw new PraxoException("TOOL_ERROR", "cart not found");
        }
        String id = "checkout-review-" + reviewSequence.incrementAndGet();
        Map<String, Object> review = new LinkedHashMap<>();
        review.put("review_id", id);
        review.put("cart_id", cartId);
        review.put("status", "review_requested");
        review.put("review_required", true);
        review.put("checkouts_executed", 0);
        reviews.put(id, review);
        return review;
    }

    public Map<String, Object> checkout(String cartId) {
        if (!carts.containsKey(cartId)) {
            throw new PraxoException("TOOL_ERROR", "cart not found");
        }
        int count = checkouts.incrementAndGet();
        return Map.of("cart_id", cartId, "status", "checked_out", "checkouts", count);
    }

    public int cartCount() {
        return carts.size();
    }

    public int reviewCount() {
        return reviews.size();
    }

    public int checkoutCount() {
        return checkouts.get();
    }

    public void reset() {
        carts.clear();
        reviews.clear();
        cartSequence.set(0);
        reviewSequence.set(0);
        checkouts.set(0);
    }
}
