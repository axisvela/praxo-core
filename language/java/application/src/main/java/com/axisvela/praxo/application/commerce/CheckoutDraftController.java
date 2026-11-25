package com.axisvela.praxo.application.commerce;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/commerce")
public final class CheckoutDraftController {
    private final CommerceAgent agent;

    public CheckoutDraftController(CommerceAgent agent) {
        this.agent = agent;
    }

    @PostMapping("/checkout-drafts")
    public ResponseEntity<Map<String, Object>> draft(
            @Valid @RequestBody CheckoutDraftRequest request,
            HttpServletRequest httpRequest) {
        String tenant = (String) httpRequest.getAttribute("tenant");
        if (tenant == null) {
            tenant = httpRequest.getHeader("X-Tenant-Id");
        }

        try {
            return ResponseEntity.ok(agent.review(tenant, request.intent()).toMap());
        } catch (ReviewFailure failure) {
            int status = switch (failure.code) {
                case "AGENT_POLICY_DENIED", "AGENT_TOOL_NOT_ALLOWED" -> 403;
                case "TOOL_ERROR" -> 503;
                default -> 500;
            };
            return ResponseEntity.status(status).body(failure.toMap());
        }
    }
}
