package io.axisvela.praxo.middleware;

import java.util.regex.Pattern;

public record PiiRule(String name, Pattern pattern, String replacement) {
    public static PiiRule of(String name, String pattern, String replacement) {
        return new PiiRule(name, Pattern.compile(pattern), replacement);
    }
}
