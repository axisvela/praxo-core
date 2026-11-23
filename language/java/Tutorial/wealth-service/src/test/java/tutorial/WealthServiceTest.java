package tutorial;

import com.axisvela.praxo.PraxoException;
import com.axisvela.praxo.util.Json;
import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.Test;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class WealthServiceTest {
    @Test
    void nativeReviewIsDraftOnly() throws Exception {
        var result = WealthService.review("acct-100", false);
        var report = Json.object(result.output());
        var draft = Json.asObject(report.get("draft"));
        assertEquals("draft_only", Json.string(draft.get("status")));
        assertEquals("review_required", Json.string(draft.get("action")));
        assertEquals(2, result.reads());
        assertTrue(((List<?>) report.get("executed_trades")).isEmpty());
    }

    @Test
    void policyDenialAndDependencyFailure() {
        var denied = assertThrows(PraxoException.class,
                () -> WealthService.review("acct-200", false));
        assertEquals("AGENT_POLICY_DENIED", denied.code);
        var failed = assertThrows(RuntimeException.class,
                () -> WealthService.review("acct-100", true));
        assertTrue(failed.getMessage().contains("simulated portfolio dependency"));
    }

    @Test
    void webBoundary() throws Exception {
        HttpServer server = WealthService.serve(0, account -> WealthService.review(account, false));
        HttpServer failing = WealthService.serve(0, account -> {
            throw new IllegalStateException("simulated downstream failure");
        });
        try {
            HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
            URI health = URI.create("http://127.0.0.1:" + server.getAddress().getPort() + "/healthz");
            var healthResponse = client.send(HttpRequest.newBuilder(health).timeout(Duration.ofSeconds(10)).GET().build(),
                    HttpResponse.BodyHandlers.ofString());
            assertEquals(200, healthResponse.statusCode());

            URI review = URI.create("http://127.0.0.1:" + server.getAddress().getPort() + "/review/acct-100");
            var denied = client.send(HttpRequest.newBuilder(review).timeout(Duration.ofSeconds(10))
                    .POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString());
            assertEquals(401, denied.statusCode());

            var allowed = client.send(HttpRequest.newBuilder(review).timeout(Duration.ofSeconds(10))
                    .header("Authorization", "Bearer demo-wealth-token")
                    .POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString());
            assertEquals(200, allowed.statusCode());
            assertTrue(allowed.body().contains("draft_only"));
            assertTrue(allowed.body().contains("executed_trades"));

            URI failingReview = URI.create("http://127.0.0.1:" + failing.getAddress().getPort() + "/review/acct-100");
            var failure = client.send(HttpRequest.newBuilder(failingReview).timeout(Duration.ofSeconds(10))
                    .header("Authorization", "Bearer demo-wealth-token")
                    .POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString());
            assertEquals(503, failure.statusCode());
        } finally {
            server.stop(0);
            failing.stop(0);
        }
    }
}
