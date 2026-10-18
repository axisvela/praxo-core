package main

import (
	"context"
	"fmt"
	"log"

	"github.com/axisvela/praxo-core/v3/pkg/agent"
	"github.com/axisvela/praxo-core/v3/pkg/model"
)

type echoModel struct{}

func (echoModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	last := req.Messages[len(req.Messages)-1]
	return model.Response{
		Message: model.Message{Role: model.RoleAssistant, Content: "echo: " + last.Content},
		Usage:   model.Usage{InputTokens: int64(len(last.Content)), OutputTokens: 1},
	}, nil
}

func main() {
	ag := &agent.Agent{Model: echoModel{}, MaxSteps: 2}
	result, err := ag.Run(context.Background(), agent.Session{ID: "example", TenantID: "local"}, "hello")
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(result.Output)
}
