package com.axisvela.praxo.util;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class Json {
    private Json() {
    }

    public static Object parse(String text) {
        Parser parser = new Parser(text);
        Object value = parser.value();
        parser.ws();
        if (parser.index != text.length()) {
            throw new IllegalArgumentException("trailing data");
        }
        return value;
    }

    public static Map<String, Object> object(String text) {
        return asObject(parse(text));
    }

    public static String stringify(Object value) {
        StringBuilder out = new StringBuilder();
        write(out, value);
        return out.toString();
    }

    @SuppressWarnings("unchecked")
    public static Map<String, Object> asObject(Object value) {
        if (value instanceof Map<?, ?> map) {
            return (Map<String, Object>) map;
        }
        throw new IllegalArgumentException("expected object");
    }

    @SuppressWarnings("unchecked")
    public static List<Object> asArray(Object value) {
        if (value instanceof List<?> list) {
            return (List<Object>) list;
        }
        throw new IllegalArgumentException("expected array");
    }

    public static String string(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof String text) {
            return text;
        }
        throw new IllegalArgumentException("expected string");
    }

    public static String string(Object object, String key) {
        return string(asObject(object).get(key));
    }

    public static List<String> strings(Object value) {
        List<String> out = new ArrayList<>();
        for (Object item : asArray(value)) {
            out.add(string(item));
        }
        return out;
    }

    public static long integer(Object value) {
        if (value instanceof Number number) {
            return number.longValue();
        }
        throw new IllegalArgumentException("expected integer");
    }

    public static int intValue(Object value) {
        return (int) integer(value);
    }

    public static double number(Object value) {
        if (value instanceof Number number) {
            return number.doubleValue();
        }
        throw new IllegalArgumentException("expected number");
    }

    public static boolean bool(Object value) {
        if (value instanceof Boolean flag) {
            return flag;
        }
        throw new IllegalArgumentException("expected boolean");
    }

    public static boolean bool(Object object, String key, boolean fallback) {
        Object value = asObject(object).get(key);
        return value == null ? fallback : bool(value);
    }

    private static void write(StringBuilder out, Object value) {
        if (value == null) {
            out.append("null");
        } else if (value instanceof String text) {
            writeString(out, text);
        } else if (value instanceof Boolean || value instanceof Number) {
            out.append(value);
        } else if (value instanceof Map<?, ?> map) {
            out.append('{');
            boolean first = true;
            for (Map.Entry<?, ?> entry : map.entrySet()) {
                if (!first) {
                    out.append(',');
                }
                first = false;
                writeString(out, String.valueOf(entry.getKey()));
                out.append(':');
                write(out, entry.getValue());
            }
            out.append('}');
        } else if (value instanceof List<?> list) {
            out.append('[');
            boolean first = true;
            for (Object item : list) {
                if (!first) {
                    out.append(',');
                }
                first = false;
                write(out, item);
            }
            out.append(']');
        } else {
            writeString(out, String.valueOf(value));
        }
    }

    private static void writeString(StringBuilder out, String text) {
        out.append('"');
        for (int index = 0; index < text.length(); index++) {
            char ch = text.charAt(index);
            switch (ch) {
                case '"' -> out.append("\\\"");
                case '\\' -> out.append("\\\\");
                case '\b' -> out.append("\\b");
                case '\f' -> out.append("\\f");
                case '\n' -> out.append("\\n");
                case '\r' -> out.append("\\r");
                case '\t' -> out.append("\\t");
                default -> {
                    if (ch < 0x20) {
                        out.append(String.format("\\u%04x", (int) ch));
                    } else {
                        out.append(ch);
                    }
                }
            }
        }
        out.append('"');
    }

    private static final class Parser {
        private final String text;
        private int index;

        private Parser(String text) {
            this.text = text;
        }

        private void ws() {
            while (index < text.length()) {
                char ch = text.charAt(index);
                if (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
                    index++;
                } else {
                    break;
                }
            }
        }

        private Object value() {
            ws();
            if (index >= text.length()) {
                throw new IllegalArgumentException("unexpected end");
            }
            char ch = text.charAt(index);
            return switch (ch) {
                case '{' -> object();
                case '[' -> array();
                case '"' -> string();
                case 't' -> literal("true", Boolean.TRUE);
                case 'f' -> literal("false", Boolean.FALSE);
                case 'n' -> literal("null", null);
                default -> number();
            };
        }

        private Object literal(String word, Object value) {
            if (!text.startsWith(word, index)) {
                throw new IllegalArgumentException("invalid literal");
            }
            index += word.length();
            return value;
        }

        private Map<String, Object> object() {
            index++;
            Map<String, Object> out = new LinkedHashMap<>();
            ws();
            if (peek('}')) {
                index++;
                return out;
            }
            while (true) {
                ws();
                String key = string();
                ws();
                expect(':');
                out.put(key, value());
                ws();
                if (peek('}')) {
                    index++;
                    return out;
                }
                expect(',');
            }
        }

        private List<Object> array() {
            index++;
            List<Object> out = new ArrayList<>();
            ws();
            if (peek(']')) {
                index++;
                return out;
            }
            while (true) {
                out.add(value());
                ws();
                if (peek(']')) {
                    index++;
                    return out;
                }
                expect(',');
            }
        }

        private String string() {
            expect('"');
            StringBuilder out = new StringBuilder();
            while (index < text.length()) {
                char ch = text.charAt(index++);
                if (ch == '"') {
                    return out.toString();
                }
                if (ch != '\\') {
                    out.append(ch);
                    continue;
                }
                if (index >= text.length()) {
                    throw new IllegalArgumentException("bad escape");
                }
                char escape = text.charAt(index++);
                switch (escape) {
                    case '"' -> out.append('"');
                    case '\\' -> out.append('\\');
                    case '/' -> out.append('/');
                    case 'b' -> out.append('\b');
                    case 'f' -> out.append('\f');
                    case 'n' -> out.append('\n');
                    case 'r' -> out.append('\r');
                    case 't' -> out.append('\t');
                    case 'u' -> {
                        if (index + 4 > text.length()) {
                            throw new IllegalArgumentException("bad unicode");
                        }
                        out.append((char) Integer.parseInt(
                                text.substring(index, index + 4), 16));
                        index += 4;
                    }
                    default -> throw new IllegalArgumentException("bad escape");
                }
            }
            throw new IllegalArgumentException("unterminated string");
        }

        private Object number() {
            int start = index;
            if (peek('-')) {
                index++;
            }
            while (index < text.length() && Character.isDigit(text.charAt(index))) {
                index++;
            }
            boolean decimal = false;
            if (index < text.length() && text.charAt(index) == '.') {
                decimal = true;
                index++;
                while (index < text.length()
                        && Character.isDigit(text.charAt(index))) {
                    index++;
                }
            }
            if (index < text.length()
                    && (text.charAt(index) == 'e' || text.charAt(index) == 'E')) {
                decimal = true;
                index++;
                if (peek('+') || peek('-')) {
                    index++;
                }
                while (index < text.length()
                        && Character.isDigit(text.charAt(index))) {
                    index++;
                }
            }
            String raw = text.substring(start, index);
            if (raw.isEmpty() || raw.equals("-")) {
                throw new IllegalArgumentException("invalid number");
            }
            if (decimal) {
                return Double.parseDouble(raw);
            }
            return Long.parseLong(raw);
        }

        private boolean peek(char ch) {
            return index < text.length() && text.charAt(index) == ch;
        }

        private void expect(char ch) {
            if (!peek(ch)) {
                throw new IllegalArgumentException("expected " + ch);
            }
            index++;
        }
    }
}
