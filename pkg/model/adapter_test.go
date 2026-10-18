package model

import (
	"context"
	"testing"
)

func TestChatModel(t *testing.T) {
	m := ChatModel{Provider: EchoProvider{}}
	resp, err := m.Generate(context.Background(), Request{Messages: []Message{{Role: RoleUser, Content: "hi"}}})
	if err != nil {
		t.Fatal(err)
	}
	if resp.Message.Content != "hi" {
		t.Fatalf("resp = %+v", resp)
	}
}
