package tutorial;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.util.Json;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class TenderReviewTest {
    @Test
    void successPath() throws Exception {
        var outcome = TenderReview.run(TenderReview.SCOPE_ID, false);
        assertEquals(1, outcome.reads());
        Map<String, Object> report = Json.object(outcome.output());
        @SuppressWarnings("unchecked")
        Map<String, Object> result = (Map<String, Object>) report.get("result");
        assertEquals("draft_only", result.get("status"));
        assertEquals(0, ((Number) result.get("writes")).intValue());
        assertEquals(0, ((Number) report.get("writes")).intValue());
    }

    @Test
    void policyDenied() {
        PraxoException error = assertThrows(PraxoException.class,
                () -> TenderReview.run("tender-200", false));
        assertEquals("AGENT_POLICY_DENIED", error.code);
    }

    @Test
    void sourceFailure() {
        Exception error = assertThrows(Exception.class,
                () -> TenderReview.run(TenderReview.SCOPE_ID, true));
        assertTrue(error.getMessage().contains(TenderReview.ERROR));
    }
}
