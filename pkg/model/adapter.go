package model

import (
	"context"
	"errors"
)

// ChatModel adapts a chat Provider to the Model interface.
type ChatModel struct {
	Provider Provider
}

// Generate implements Model by calling Provider.Chat.
func (m ChatModel) Generate(ctx context.Context, req Request) (Response, error) {
	if m.Provider == nil {
		return Response{}, errors.New("model: provider is required")
	}
	if err := ctx.Err(); err != nil {
		return Response{}, err
	}
	messages, err := m.Provider.Chat(req.Messages)
	if err != nil {
		return Response{}, err
	}
	if len(messages) == 0 {
		return Response{}, errors.New("model: provider returned no messages")
	}
	return Response{Message: messages[len(messages)-1]}, nil
}
