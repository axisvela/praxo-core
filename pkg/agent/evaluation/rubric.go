package evaluation

import (
	"context"
	"errors"
	"fmt"

	"github.com/axisvela/praxo-core/v2/pkg/agent/types"
)

// Criterion is one rubric dimension.
type Criterion struct {
	ID          string
	Description string
	Weight      float64
}

// Rubric defines a pass/fail evaluation of a final output.
type Rubric struct {
	ID        string
	Criteria  []Criterion
	PassScore float64
}

// Evaluation is the result of one rubric pass.
type Evaluation struct {
	RubricID string
	Score    float64
	Passed   bool
	Details  map[string]float64
	Reason   string
}

// Evaluator scores an output against a rubric. Products may implement it with
// a grader model or deterministic checks.
type Evaluator interface {
	Evaluate(ctx context.Context, rubric Rubric, output string) (Evaluation, error)
}

// ErrRubricFailed reports a final output below the rubric pass score.
var ErrRubricFailed = errors.New("agent: rubric failed")

// RubricMiddleware evaluates a completed run and fails it when the rubric does
// not pass. onEvaluation is optional observability.
func RubricMiddleware(rubric Rubric, evaluator Evaluator, onEvaluation func(Evaluation) error) types.Middleware {
	return types.Middleware{
		Name: "rubric",
		AfterRun: func(ctx context.Context, result *types.Result, runErr error) error {
			if runErr != nil || result == nil || evaluator == nil {
				return nil
			}
			evaluation, err := evaluator.Evaluate(ctx, rubric, result.Output)
			if err != nil {
				return err
			}
			if evaluation.RubricID == "" {
				evaluation.RubricID = rubric.ID
			}
			if onEvaluation != nil {
				if err := onEvaluation(evaluation); err != nil {
					return err
				}
			}
			if !evaluation.Passed {
				return fmt.Errorf("%w: %s score %.2f < %.2f", ErrRubricFailed, rubric.ID, evaluation.Score, rubric.PassScore)
			}
			return nil
		},
	}
}
