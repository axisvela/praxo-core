package io.axisvela.praxo.policy;

public record Decision(boolean allowed, String reason) {
    public static Decision allow(String reason) {
        return new Decision(true, reason);
    }

    public static Decision deny(String reason) {
        return new Decision(false, reason);
    }
}
