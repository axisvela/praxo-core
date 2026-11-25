package com.axisvela.praxo.application.commerce;

import com.axisvela.praxo.PraxoException;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

@Service
public final class CatalogService {
    private static final List<Map<String, Object>> PRODUCTS = List.of(
            Map.of(
                    "sku", "sku-100",
                    "name", "Trail Running Shoe",
                    "price", 129.0,
                    "currency", "USD",
                    "category", "footwear"),
            Map.of(
                    "sku", "sku-101",
                    "name", "All-Weather Jacket",
                    "price", 189.0,
                    "currency", "USD",
                    "category", "outerwear"));

    private final CommerceSettings settings;

    public CatalogService(CommerceSettings settings) {
        this.settings = settings;
    }

    public List<Map<String, Object>> search(String query) {
        failIfConfigured();
        return PRODUCTS;
    }

    public Map<String, Object> product(String sku) {
        failIfConfigured();
        for (Map<String, Object> product : PRODUCTS) {
            if (sku.equals(product.get("sku"))) {
                return product;
            }
        }
        throw new PraxoException("TOOL_ERROR", "sku not found");
    }

    public Map<String, Object> inventory(String sku) {
        Map<String, Object> product = product(sku);
        return Map.of(
                "sku", sku,
                "available", 12,
                "warehouse", "us-east",
                "product", product);
    }

    private void failIfConfigured() {
        if (settings.catalogFailure()) {
            throw new PraxoException("TOOL_ERROR", "catalog search unavailable");
        }
    }
}
