package tutorial;

import com.axisvela.praxo.util.Json;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class LegacyMigrationTest {
    @Test
    void successPath() throws Exception {
        var outcome = LegacyMigration.run(LegacyMigration.SCOPE_ID, false);
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
        Exception error = assertThrows(Exception.class,
                () -> LegacyMigration.run("module-200", false));
        assertTrue(error.getMessage().contains("AGENT_POLICY_DENIED"));
    }

    @Test
    void sourceFailure() {
        Exception error = assertThrows(Exception.class,
                () -> LegacyMigration.run(LegacyMigration.SCOPE_ID, true));
        assertTrue(error.getMessage().contains(LegacyMigration.ERROR));
    }
}
