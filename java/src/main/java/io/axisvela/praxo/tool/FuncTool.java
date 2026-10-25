package io.axisvela.praxo.tool;

import java.util.Map;
import java.util.function.Function;

public record FuncTool(
        String name,
        String description,
        Function<Map<String, Object>, Object> function) implements Tool {

    @Override
    public Object invoke(Map<String, Object> args) {
        return function.apply(args);
    }
}
