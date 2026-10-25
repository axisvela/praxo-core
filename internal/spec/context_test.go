package spec

import (
	"encoding/json"
	"fmt"
	"reflect"

	agentcontext "github.com/axisvela/praxo-core/v2/pkg/agent/context"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func runContext(v vectorCase) error {
	var in struct {
		Operation string          `json:"operation"`
		Messages  []model.Message `json:"messages"`
		Budget    struct {
			MaxTokens  int `json:"maxTokens"`
			KeepRecent int `json:"keepRecent"`
		} `json:"budget"`
	}
	var exp struct {
		OK       bool            `json:"ok"`
		Tokens   int             `json:"tokens"`
		Messages []model.Message `json:"messages"`
	}
	if err := json.Unmarshal(v.Input, &in); err != nil {
		return err
	}
	if err := json.Unmarshal(v.Expect, &exp); err != nil {
		return err
	}

	switch in.Operation {
	case "estimate":
		got := agentcontext.EstimateTokens(in.Messages)
		if got != exp.Tokens {
			return fmt.Errorf("tokens: got %d want %d", got, exp.Tokens)
		}
		return nil
	case "compact":
		budget := agentcontext.ContextBudget{
			MaxTokens:  in.Budget.MaxTokens,
			KeepRecent: in.Budget.KeepRecent,
		}
		out, ok := budget.Compact(in.Messages)
		if ok != exp.OK {
			return fmt.Errorf("ok: got %v want %v", ok, exp.OK)
		}
		if !ok {
			return nil
		}
		if got := agentcontext.EstimateTokens(out); got != exp.Tokens {
			return fmt.Errorf("tokens: got %d want %d", got, exp.Tokens)
		}
		if !reflect.DeepEqual(out, exp.Messages) {
			return fmt.Errorf("messages: got %#v want %#v", out, exp.Messages)
		}
		return nil
	default:
		return fmt.Errorf("unknown context operation %q", in.Operation)
	}
}
