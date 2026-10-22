package mcp

import (
	"context"
	"errors"
	"testing"

	sdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

func infoResource(_ context.Context, req *sdk.ReadResourceRequest) (*sdk.ReadResourceResult, error) {
	return &sdk.ReadResourceResult{Contents: []*sdk.ResourceContents{{
		URI:      req.Params.URI,
		MIMEType: "text/plain",
		Text:     "hello",
	}}}, nil
}

func greetPrompt(_ context.Context, req *sdk.GetPromptRequest) (*sdk.GetPromptResult, error) {
	return &sdk.GetPromptResult{Messages: []*sdk.PromptMessage{{
		Role:    "user",
		Content: &sdk.TextContent{Text: "hi " + req.Params.Arguments["name"]},
	}}}, nil
}

func newContentSession(t *testing.T) *sdk.ClientSession {
	t.Helper()
	ctx := context.Background()
	serverTransport, clientTransport := sdk.NewInMemoryTransports()

	server := sdk.NewServer(&sdk.Implementation{Name: "content-server", Version: "v0.0.1"}, nil)
	server.AddResource(&sdk.Resource{
		Name:        "info",
		URI:         "embedded:info",
		MIMEType:    "text/plain",
		Description: "Example resource",
	}, infoResource)
	server.AddPrompt(&sdk.Prompt{
		Name:        "greet",
		Description: "Greet someone",
		Arguments:   []*sdk.PromptArgument{{Name: "name", Required: true}},
	}, greetPrompt)

	serverSession, err := server.Connect(ctx, serverTransport, nil)
	if err != nil {
		t.Fatal(err)
	}
	client := sdk.NewClient(&sdk.Implementation{Name: "content-client", Version: "v0.0.1"}, nil)
	clientSession, err := client.Connect(ctx, clientTransport, nil)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		_ = clientSession.Close()
		_ = serverSession.Wait()
	})
	return clientSession
}

func TestResourcesAndPrompts(t *testing.T) {
	ctx := context.Background()
	session := newContentSession(t)

	resources, err := ListResources(ctx, session)
	if err != nil {
		t.Fatal(err)
	}
	if len(resources) != 1 || resources[0].URI != "embedded:info" || resources[0].MIMEType != "text/plain" {
		t.Fatalf("resources = %#v", resources)
	}

	contents, err := ReadResource(ctx, session, "embedded:info")
	if err != nil {
		t.Fatal(err)
	}
	if len(contents) != 1 || contents[0].Text != "hello" {
		t.Fatalf("contents = %#v", contents)
	}

	prompts, err := ListPrompts(ctx, session)
	if err != nil {
		t.Fatal(err)
	}
	if len(prompts) != 1 || prompts[0].Name != "greet" || len(prompts[0].Arguments) != 1 {
		t.Fatalf("prompts = %#v", prompts)
	}
	if prompts[0].Arguments[0].Name != "name" || !prompts[0].Arguments[0].Required {
		t.Fatalf("arguments = %#v", prompts[0].Arguments)
	}

	messages, err := GetPrompt(ctx, session, "greet", map[string]string{"name": "Ada"})
	if err != nil {
		t.Fatal(err)
	}
	if len(messages) != 1 || messages[0].Role != "user" || messages[0].Text != "hi Ada" {
		t.Fatalf("messages = %#v", messages)
	}
}

func TestResourcesRequireSession(t *testing.T) {
	ctx := context.Background()
	if _, err := ListResources(ctx, nil); !errors.Is(err, ErrSessionRequired) {
		t.Fatalf("ListResources: %v", err)
	}
	if _, err := ReadResource(ctx, nil, "embedded:info"); !errors.Is(err, ErrSessionRequired) {
		t.Fatalf("ReadResource: %v", err)
	}
	if _, err := ListPrompts(ctx, nil); !errors.Is(err, ErrSessionRequired) {
		t.Fatalf("ListPrompts: %v", err)
	}
	if _, err := GetPrompt(ctx, nil, "greet", nil); !errors.Is(err, ErrSessionRequired) {
		t.Fatalf("GetPrompt: %v", err)
	}
}
