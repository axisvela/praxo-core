package io.axisvela.praxo.middleware;

import io.axisvela.praxo.model.Model;
import io.axisvela.praxo.model.Request;
import io.axisvela.praxo.model.Response;

public final class FallbackModel {
    private FallbackModel() {
    }

    public static Middleware.ModelMiddleware fallback(Model fallback) {
        return next -> request -> {
            try {
                return next.handle(request);
            } catch (Exception primary) {
                if (fallback == null) {
                    throw primary;
                }
                try {
                    return fallback.generate(request);
                } catch (Exception secondary) {
                    primary.addSuppressed(secondary);
                    throw primary;
                }
            }
        };
    }
}
