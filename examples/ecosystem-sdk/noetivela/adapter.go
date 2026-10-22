// Package noetivela adapts the NOETIVELA Go SDK to the PRAXO-CORE model seam.
package noetivela

import (
	"context"
	"errors"

	noetivela "github.com/axisvela/noetivela-open/sdk/go/v3/client"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// ErrClientRequired is returned when the SDK client is not configured.
var ErrClientRequired = errors.New("noetivela: client is required")

// Adapter implements model.Model with a NOETIVELA SDK client.
type Adapter struct {
	Client       *noetivela.Client
	Model        string
	Policy       string
	ContractFunc func(model.Request) *noetivela.Contract
}

// Generate sends a governed chat request through the NOETIVELA SDK.
func (a Adapter) Generate(ctx context.Context, req model.Request) (model.Response, error) {
	if a.Client == nil {
		return model.Response{}, ErrClientRequired
	}
	client := a.Client
	if a.Policy != "" {
		clientCopy := *client
		clientCopy.PolicyName = a.Policy
		client = &clientCopy
	}
	if a.ContractFunc != nil {
		if contract := a.ContractFunc(req); contract != nil {
			client = client.WithContract(contract)
		}
	}
	name := a.Model
	if name == "" {
		name = req.Model
	}
	if name == "" {
		name = "auto"
	}
	messages := make([]noetivela.Message, 0, len(req.Messages))
	for _, message := range req.Messages {
		messages = append(messages, noetivela.Message{
			Role:    message.Role,
			Content: message.Content,
		})
	}
	response, err := client.Chat(ctx, name, messages)
	if err != nil {
		return model.Response{}, err
	}
	return model.Response{
		Message: model.Message{
			Role:    model.RoleAssistant,
			Content: response.Content,
		},
		Usage: model.Usage{
			InputTokens:  response.Usage.InputTokens,
			OutputTokens: response.Usage.OutputTokens,
			CachedTokens: response.Usage.CachedTokens,
		},
		FinishReason: response.FinishReason,
	}, nil
}
