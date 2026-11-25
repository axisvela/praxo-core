package com.axisvela.praxo.application.commerce;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = "praxo.commerce.catalog-failure=true")
@AutoConfigureMockMvc
class CatalogFailureTest {
    @Autowired
    private MockMvc mockMvc;

    @Test
    void catalogFailureReturns503WithoutDraft() throws Exception {
        mockMvc.perform(post("/api/commerce/checkout-drafts")
                        .header("X-Tenant-Id", "acme")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"intent\":\"Find a trail running shoe.\"}"))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error").value("TOOL_ERROR"))
                .andExpect(jsonPath("$.agent.reads").value(1))
                .andExpect(jsonPath("$.agent.drafts").value(0))
                .andExpect(jsonPath("$.agent.reviews").value(0))
                .andExpect(jsonPath("$.agent.checkouts").value(0));
    }
}
