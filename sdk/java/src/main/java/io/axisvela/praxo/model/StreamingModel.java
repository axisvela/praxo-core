package io.axisvela.praxo.model;

import java.util.function.Consumer;

public interface StreamingModel extends Model {
    Response generateStream(Request request, Consumer<String> onDelta) throws Exception;
}
