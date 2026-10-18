package middleware

import (
	"context"
	"errors"

	"github.com/axisvela/praxo-core/pkg/agent/types"
	"github.com/axisvela/praxo-core/pkg/model"
)

// FallbackModel returns a model middleware that retries a failed primary call
// against a fallback model. The fallback receives the same request and its
// error is returned when it also fails.
func FallbackModel(fallback model.Model) types.ModelMiddleware {
	return func(next func(context.Context, model.Request) (model.Response, error)) func(context.Context, model.Request) (model.Response, error) {
		return func(ctx context.Context, req model.Request) (model.Response, error) {
			resp, err := next(ctx, req)
			if err == nil {
				return resp, nil
			}
			if fallback == nil {
				return resp, err
			}
			resp, fallbackErr := fallback.Generate(ctx, req)
			if fallbackErr != nil {
				return resp, errors.Join(err, fallbackErr)
			}
			return resp, nil
		}
	}
}
