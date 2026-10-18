package evaluation

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/pkg/agent/types"
)

type fakeEvaluator struct {
	evaluation Evaluation
	err        error
}

func (f fakeEvaluator) Evaluate(context.Context, Rubric, string) (Evaluation, error) {
	return f.evaluation, f.err
}

func TestRubricMiddlewarePasses(t *testing.T) {
	var observed Evaluation
	mw := RubricMiddleware(Rubric{ID: "r1", PassScore: 0.8}, fakeEvaluator{evaluation: Evaluation{Score: 0.9, Passed: true}}, func(e Evaluation) error {
		observed = e
		return nil
	})
	err := mw.AfterRun(context.Background(), &types.Result{Output: "ok"}, nil)
	if err != nil {
		t.Fatal(err)
	}
	if observed.RubricID != "r1" || observed.Score != 0.9 {
		t.Fatalf("observed = %+v", observed)
	}
}

func TestRubricMiddlewareFails(t *testing.T) {
	mw := RubricMiddleware(Rubric{ID: "r1", PassScore: 0.8}, fakeEvaluator{evaluation: Evaluation{Score: 0.2, Passed: false}}, nil)
	err := mw.AfterRun(context.Background(), &types.Result{Output: "bad"}, nil)
	if !errors.Is(err, ErrRubricFailed) {
		t.Fatalf("err = %v, want ErrRubricFailed", err)
	}
}

func TestRubricMiddlewareSkipsRunError(t *testing.T) {
	mw := RubricMiddleware(Rubric{ID: "r1", PassScore: 0.8}, fakeEvaluator{evaluation: Evaluation{Score: 0.2}}, nil)
	if err := mw.AfterRun(context.Background(), &types.Result{}, errors.New("run failed")); err != nil {
		t.Fatalf("err = %v, want nil", err)
	}
}

func TestRubricMiddlewareEvaluatorError(t *testing.T) {
	sentinel := errors.New("grader down")
	mw := RubricMiddleware(Rubric{ID: "r1"}, fakeEvaluator{err: sentinel}, nil)
	if err := mw.AfterRun(context.Background(), &types.Result{}, nil); !errors.Is(err, sentinel) {
		t.Fatalf("err = %v, want sentinel", err)
	}
}
