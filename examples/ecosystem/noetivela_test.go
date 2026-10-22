package ecosystem

import (
	"context"
	"errors"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

var _ model.Model = Noetivela{}

func TestNoetivelaUnconfigured(t *testing.T) {
	if _, err := (Noetivela{}).Generate(context.Background(), model.Request{}); !errors.Is(err, ErrNotConfigured) {
		t.Fatalf("got %v, want %v", err, ErrNotConfigured)
	}
}

func TestNoetivelaMapsContract(t *testing.T) {
	var gotContract InferenceContract
	adapter := Noetivela{
		ContractFunc: func(req model.Request) InferenceContract {
			return InferenceContract{
				Task:           req.Model,
				Modality:       []string{"text"},
				AllowedRegions: []string{"sg"},
				DataClass:      "internal",
			}
		},
		ChatFunc: func(_ context.Context, contract InferenceContract, messages []model.Message) (model.Response, error) {
			gotContract = contract
			return model.Response{Message: model.Message{
				Role:    model.RoleAssistant,
				Content: messages[len(messages)-1].Content,
			}}, nil
		},
	}

	response, err := adapter.Generate(context.Background(), model.Request{
		Model:    "status_lookup",
		Messages: []model.Message{{Role: model.RoleUser, Content: "check status"}},
	})
	if err != nil {
		t.Fatal(err)
	}
	if gotContract.Task != "status_lookup" || gotContract.DataClass != "internal" {
		t.Fatalf("contract = %#v", gotContract)
	}
	if len(gotContract.Modality) != 1 || gotContract.Modality[0] != "text" {
		t.Fatalf("modality = %#v", gotContract.Modality)
	}
	if response.Message.Content != "check status" {
		t.Fatalf("content = %q", response.Message.Content)
	}
}
