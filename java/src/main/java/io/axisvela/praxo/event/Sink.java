package io.axisvela.praxo.event;

import java.util.List;

public interface Sink {
    void emit(Event event) throws Exception;

    static Sink multi(List<Sink> sinks) {
        return event -> {
            for (Sink sink : sinks) {
                if (sink != null) {
                    sink.emit(event);
                }
            }
        };
    }

    static Sink filter(Sink sink, java.util.function.Predicate<Event> predicate) {
        return event -> {
            if (sink == null) {
                return;
            }
            if (predicate != null && !predicate.test(event)) {
                return;
            }
            sink.emit(event);
        };
    }
}
