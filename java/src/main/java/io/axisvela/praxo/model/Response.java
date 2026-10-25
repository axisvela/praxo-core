package io.axisvela.praxo.model;

public record Response(Message message, Usage usage, String finishReason) {
    public Response {
        usage = usage == null ? Usage.zero() : usage;
    }

    public static Response of(Message message) {
        return new Response(message, Usage.zero(), null);
    }
}
