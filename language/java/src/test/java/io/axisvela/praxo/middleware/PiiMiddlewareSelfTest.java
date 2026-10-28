package io.axisvela.praxo.middleware;

import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.ToolCall;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class PiiMiddlewareSelfTest {
    private PiiMiddlewareSelfTest() {
    }

    public static void main(String[] args) {
        Map<String, Object> nested = new LinkedHashMap<>();
        nested.put("ssn", "123-45-6789");
        Map<String, Object> original = new LinkedHashMap<>();
        original.put("email", "a@b.com");
        original.put("nested", nested);

        Message message = Message.assistant(
                "", List.of(new ToolCall("call-1", "lookup", original)));
        ModelCall call = new ModelCall(
                "r1", "s1", Request.of(List.of(message)));
        new PiiMiddleware(PiiRedactor.defaults()).beforeModel(call);

        Map<String, Object> redacted = call.request.messages()
                .get(0).toolCalls().get(0).arguments();
        require("[REDACTED:email]".equals(redacted.get("email")),
                "top-level email was not redacted");
        @SuppressWarnings("unchecked")
        Map<String, Object> redactedNested =
                (Map<String, Object>) redacted.get("nested");
        require("[REDACTED:ssn]".equals(redactedNested.get("ssn")),
                "nested ssn was not redacted");
        require("a@b.com".equals(original.get("email")),
                "caller arguments were mutated");
        System.out.println("pii middleware self-test passed");
    }

    private static void require(boolean condition, String message) {
        if (!condition) {
            throw new AssertionError(message);
        }
    }
}
