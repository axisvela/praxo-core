package ecosystem

import (
	"context"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// InferenceContract is the minimal adapter-side shape for a NOETIVELA contract.
type InferenceContract struct {
	Task           string
	Modality       []string
	AllowedRegions []string
	DataClass      string
}

// Noetivela adapts a NOETIVELA inference client to model.Model. The agent does
// not set model.Request.Model, so derive contract fields from adapter state,
// run context, or messages.
type Noetivela struct {
	ContractFunc func(model.Request) InferenceContract
	ChatFunc     func(context.Context, InferenceContract, []model.Message) (model.Response, error)
}

// Generate maps the neutral request to a contract and calls ChatFunc.
func (n Noetivela) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	if n.ChatFunc == nil {
		return model.Response{}, ErrNotConfigured
	}
	var contract InferenceContract
	if n.ContractFunc != nil {
		contract = n.ContractFunc(req)
	}
	return n.ChatFunc(ctx, contract, req.Messages)
}
