package io.axisvela.praxo.middleware;

import io.axisvela.praxo.model.ContentBlock;
import io.axisvela.praxo.model.Message;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.ToolCall;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public final class PiiMiddleware implements Middleware {
    private final PiiRedactor redactor;

    public PiiMiddleware(PiiRedactor redactor) {
        this.redactor = redactor;
    }

    @Override
    public String name() {
        return "pii";
    }

    @Override
    public void beforeModel(ModelCall call) {
        if (call.request == null) {
            return;
        }
        List<Message> messages = new ArrayList<>();
        for (Message message : call.request.messages()) {
            List<ContentBlock> blocks = new ArrayList<>();
            for (ContentBlock block : message.contentBlocks()) {
                blocks.add(new ContentBlock(
                        block.type(),
                        redactor.redact(block.text()),
                        block.imageUrl(),
                        block.data()));
            }
            List<ToolCall> calls = new ArrayList<>();
            for (ToolCall call : message.toolCalls()) {
                @SuppressWarnings("unchecked")
                Map<String, Object> arguments =
                        (Map<String, Object>) redactor.redactValue(
                                call.arguments());
                calls.add(new ToolCall(call.id(), call.name(), arguments));
            }
            messages.add(new Message(
                    message.role(),
                    redactor.redact(message.content()),
                    blocks,
                    calls,
                    message.toolId()));
        }
        call.request = new Request(
                call.request.model(), messages, call.request.tools(),
                call.request.toolChoice(), call.request.responseFormat(),
                call.request.cacheHint(), call.request.temperature());
    }

    @Override
    public void afterTool(MiddlewareToolCall call, ToolResult result) {
        result.value = redactor.redactValue(result.value);
    }
}
