package com.axisvela.praxo.application.commerce;

import com.axisvela.praxo.model.Message;
import com.axisvela.praxo.model.Model;
import com.axisvela.praxo.model.Response;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class CommerceApplicationTests {
    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private DraftService drafts;

    @Autowired
    private CatalogService catalog;

    @Autowired
    private CommerceSettings settings;

    @BeforeEach
    void resetState() {
        drafts.reset();
    }

    @Test
    void aiCommerceDraftCreatesReviewOnlyPackage() throws Exception {
        mockMvc.perform(post("/api/commerce/checkout-drafts")
                        .header("X-Tenant-Id", "acme")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"intent\":\"Find a trail running shoe for a weekend hike.\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.report.cart.status").value("draft_only"))
                .andExpect(jsonPath("$.report.cart.rationale").isNotEmpty())
                .andExpect(jsonPath("$.report.review.status").value("review_requested"))
                .andExpect(jsonPath("$.report.checkouts_executed").value(0))
                .andExpect(jsonPath("$.report.review.checkouts_executed").value(0))
                .andExpect(jsonPath("$.report.model").value("deterministic"))
                .andExpect(jsonPath("$.report.agent_trace").isArray())
                .andExpect(jsonPath("$.report.agent_trace").isNotEmpty())
                .andExpect(jsonPath("$.report.agent_trace[1].tool_calls[0].name").value("search_catalog"))
                .andExpect(jsonPath("$.report.agent_trace[2].model_output.tool_calls[0].name").value("draft_cart"))
                .andExpect(jsonPath("$.agent.reads").value(2))
                .andExpect(jsonPath("$.agent.drafts").value(1))
                .andExpect(jsonPath("$.agent.reviews").value(1))
                .andExpect(jsonPath("$.agent.checkouts").value(0));

        assertEquals(1, drafts.cartCount());
        assertEquals(1, drafts.reviewCount());
        assertEquals(0, drafts.checkoutCount());
    }

    @Test
    void missingTenantIsRejectedBeforeRetrieval() throws Exception {
        mockMvc.perform(post("/api/commerce/checkout-drafts")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"intent\":\"Find a trail running shoe.\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("TENANT_REQUIRED"));
    }

    @Test
    void mismatchedTenantIsRejectedBeforeRetrieval() throws Exception {
        mockMvc.perform(post("/api/commerce/checkout-drafts")
                        .header("X-Tenant-Id", "other")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"intent\":\"Find a trail running shoe.\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("TENANT_DENIED"));
    }

    @Test
    void directCheckoutIsDeniedBeforeAnyEffect() throws Exception {
        mockMvc.perform(post("/api/commerce/checkout-drafts")
                        .header("X-Tenant-Id", "acme")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"intent\":\"Checkout now for the trail running shoe.\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error").value("AGENT_POLICY_DENIED"))
                .andExpect(jsonPath("$.agent.reads").value(0))
                .andExpect(jsonPath("$.agent.drafts").value(0))
                .andExpect(jsonPath("$.agent.reviews").value(0))
                .andExpect(jsonPath("$.agent.checkouts").value(0));

        assertEquals(0, drafts.cartCount());
        assertEquals(0, drafts.checkoutCount());
    }

    @Test
    void missingIntentFailsValidation() throws Exception {
        mockMvc.perform(post("/api/commerce/checkout-drafts")
                        .header("X-Tenant-Id", "acme")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void invalidModelOutputIsRejected() {
        Model invalid = request -> Response.of(Message.assistant("not-json", List.of()));
        CommerceAgent agent = new CommerceAgent(catalog, drafts, settings, invalid);

        ReviewFailure failure = assertThrows(
                ReviewFailure.class,
                () -> agent.review("acme", "Find a trail running shoe."));

        assertEquals("AGENT_INVALID_OUTPUT", failure.code);
        assertEquals(0, failure.reads);
        assertEquals(0, failure.drafts);
        assertEquals(0, failure.reviews);
        assertEquals(0, failure.checkouts);
    }
}
