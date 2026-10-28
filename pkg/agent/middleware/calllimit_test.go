package middleware

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/internal/runid"
	"github.com/axisvela/praxo-core/v2/pkg/agent/types"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func TestCallLimitMiddlewareModelLimit(t *testing.T) {
	mw := CallLimitMiddleware(1, 0)
	state := &types.RunState{RunID: "run-1"}
	if err := mw.BeforeRun(context.Background(), state); err != nil {
		t.Fatal(err)
	}
	call := &types.ModelCall{RunID: "run-1", Request: &model.Request{}}
	if err := mw.BeforeModel(context.Background(), call); err != nil {
		t.Fatalf("first model call: %v", err)
	}
	if err := mw.BeforeModel(context.Background(), call); !errors.Is(err, ErrModelCallLimit) {
		t.Fatalf("err = %v, want ErrModelCallLimit", err)
	}
}

func TestCallLimitMiddlewareToolLimit(t *testing.T) {
	mw := CallLimitMiddleware(0, 1)
	if err := mw.BeforeRun(context.Background(), &types.RunState{RunID: "run-2"}); err != nil {
		t.Fatal(err)
	}
	call := &types.ToolCall{RunID: "run-2", Call: &model.ToolCall{Name: "echo"}}
	if err := mw.BeforeTool(context.Background(), call); err != nil {
		t.Fatalf("first tool call: %v", err)
	}
	if err := mw.BeforeTool(context.Background(), call); !errors.Is(err, ErrToolCallLimit) {
		t.Fatalf("err = %v, want ErrToolCallLimit", err)
	}
}

func TestCallLimitMiddlewareSeparatesRuns(t *testing.T) {
	mw := CallLimitMiddleware(1, 0)
	if err := mw.BeforeRun(context.Background(), &types.RunState{RunID: "a"}); err != nil {
		t.Fatal(err)
	}
	if err := mw.BeforeRun(context.Background(), &types.RunState{RunID: "b"}); err != nil {
		t.Fatal(err)
	}
	callA := &types.ModelCall{RunID: "a", Request: &model.Request{}}
	callB := &types.ModelCall{RunID: "b", Request: &model.Request{}}
	if err := mw.BeforeModel(context.Background(), callA); err != nil {
		t.Fatal(err)
	}
	if err := mw.BeforeModel(context.Background(), callB); err != nil {
		t.Fatalf("second run was affected by first: %v", err)
	}
}

func TestCallLimitMiddlewareCleansFailedRunWithoutResult(t *testing.T) {
	ctx := runid.With(context.Background(), "failed")
	mw := CallLimitMiddleware(1, 1)
	if err := mw.BeforeRun(ctx, &types.RunState{RunID: "failed"}); err != nil {
		t.Fatal(err)
	}
	modelCall := &types.ModelCall{RunID: "failed"}
	toolCall := &types.ToolCall{RunID: "failed"}
	if err := mw.BeforeModel(ctx, modelCall); err != nil {
		t.Fatal(err)
	}
	if err := mw.BeforeTool(ctx, toolCall); err != nil {
		t.Fatal(err)
	}
	if err := mw.AfterRun(ctx, nil, context.Canceled); err != nil {
		t.Fatal(err)
	}
	if err := mw.BeforeModel(ctx, modelCall); err != nil {
		t.Fatalf("failed run model count was retained: %v", err)
	}
	if err := mw.BeforeTool(ctx, toolCall); err != nil {
		t.Fatalf("failed run tool count was retained: %v", err)
	}
}
