package tutorial;

import com.sun.net.httpserver.HttpServer;
import com.axisvela.praxo.tool.Registry;
import org.junit.jupiter.api.Test;

import java.net.InetSocketAddress;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

class OrderReviewTest {
    @Test
    void registryRetainsToolSchema() {
        Registry tools = new Registry();
        tools.register(new OrderReview.ReviewTool("http://127.0.0.1:8765", "demo-a-token"));
        assertNotNull(tools.specs().get(0).parameters());
        assertEquals("write", tools.specs().get(0).risk());
    }

    @Test
    void nativeAgentAndWebBoundary() throws Exception {
        AtomicInteger reads = new AtomicInteger();
        AtomicInteger writes = new AtomicInteger();
        HttpServer backend = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        backend.createContext("/v1/orders/order-100", exchange -> {
            boolean write = "POST".equals(exchange.getRequestMethod());
            if (write) writes.incrementAndGet(); else reads.incrementAndGet();
            byte[] body = (write ? "{\"status\":\"draft_only\"}"
                    : "{\"id\":\"order-100\",\"status\":\"delayed\"}")
                    .getBytes(StandardCharsets.UTF_8);
            exchange.getRequestBody().readAllBytes();
            exchange.sendResponseHeaders(write ? 201 : 200, body.length);
            try (var output = exchange.getResponseBody()) { output.write(body); }
            finally { exchange.close(); }
        });
        backend.start();
        String origin = "http://127.0.0.1:" + backend.getAddress().getPort();
        HttpServer web = null;
        try {
            assertTrue(OrderReview.review(origin, "demo-a-token", "order-100").contains("draft_only"));
            assertEquals(1, writes.get());
            assertThrows(Exception.class, () -> OrderReview.review(origin, "demo-a-token", "order-200"));
            assertEquals(1, reads.get());
            assertEquals(1, writes.get());
            web = OrderReview.serve(origin, "demo-a-token", 0);
            URI endpoint = URI.create("http://127.0.0.1:" + web.getAddress().getPort() + "/review/order-100");
            HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
            var denied = client.send(HttpRequest.newBuilder(endpoint).timeout(Duration.ofSeconds(10))
                    .POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString());
            assertEquals(401, denied.statusCode());
            assertEquals(1, writes.get());
            var allowed = client.send(HttpRequest.newBuilder(endpoint).timeout(Duration.ofSeconds(10))
                    .header("Authorization", "Bearer demo-a-token")
                    .POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString());
            assertEquals(200, allowed.statusCode());
            assertTrue(allowed.body().contains("draft_only"));
            assertEquals(2, writes.get());
            backend.stop(0);
            var unavailable = client.send(HttpRequest.newBuilder(endpoint).timeout(Duration.ofSeconds(10))
                    .header("Authorization", "Bearer demo-a-token")
                    .POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString());
            assertEquals(503, unavailable.statusCode());
            assertEquals(2, writes.get());
        } finally {
            if (web != null) web.stop(0);
            backend.stop(0);
        }
    }
}
