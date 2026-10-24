package main

import (
	"context"
	"fmt"
	"log"

	mcpx "github.com/axisvela/praxo-core/adapters/mcp"
	sdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

type result struct {
	Resources []mcpx.Resource
	Contents  []mcpx.ResourceContent
	Prompts   []mcpx.Prompt
	Messages  []mcpx.PromptMessage
}

func main() {
	summary, err := run(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("resources:")
	for _, item := range summary.Resources {
		fmt.Printf("  %s (%s)\n", item.URI, item.MIMEType)
	}
	fmt.Println("contents:")
	for _, item := range summary.Contents {
		fmt.Printf("  %s: %s\n", item.URI, item.Text)
	}
	fmt.Println("prompts:")
	for _, item := range summary.Prompts {
		fmt.Printf("  %s: %s\n", item.Name, item.Description)
	}
	fmt.Println("messages:")
	for _, item := range summary.Messages {
		fmt.Printf("  %s: %s\n", item.Role, item.Text)
	}
}

func run(ctx context.Context) (result, error) {
	serverTransport, clientTransport := sdk.NewInMemoryTransports()

	server := sdk.NewServer(&sdk.Implementation{Name: "ecosystem-demo", Version: "v0.0.1"}, nil)
	server.AddResource(&sdk.Resource{
		Name:        "status",
		URI:         "demo:status",
		MIMEType:    "text/plain",
		Description: "Current demo status",
	}, readStatus)
	server.AddPrompt(&sdk.Prompt{
		Name:        "summarize",
		Description: "Summarize a topic",
		Arguments:   []*sdk.PromptArgument{{Name: "topic", Required: true}},
	}, summarize)

	serverSession, err := server.Connect(ctx, serverTransport, nil)
	if err != nil {
		return result{}, err
	}
	defer serverSession.Wait()

	client := sdk.NewClient(&sdk.Implementation{Name: "praxo-demo", Version: "v0.0.1"}, nil)
	session, err := client.Connect(ctx, clientTransport, nil)
	if err != nil {
		return result{}, err
	}
	defer session.Close()

	resources, err := mcpx.ListResources(ctx, session)
	if err != nil {
		return result{}, err
	}
	contents, err := mcpx.ReadResource(ctx, session, "demo:status")
	if err != nil {
		return result{}, err
	}
	prompts, err := mcpx.ListPrompts(ctx, session)
	if err != nil {
		return result{}, err
	}
	messages, err := mcpx.GetPrompt(ctx, session, "summarize", map[string]string{"topic": "release"})
	if err != nil {
		return result{}, err
	}
	return result{
		Resources: resources,
		Contents:  contents,
		Prompts:   prompts,
		Messages:  messages,
	}, nil
}

func readStatus(_ context.Context, req *sdk.ReadResourceRequest) (*sdk.ReadResourceResult, error) {
	return &sdk.ReadResourceResult{Contents: []*sdk.ResourceContents{{
		URI:      req.Params.URI,
		MIMEType: "text/plain",
		Text:     "status: green",
	}}}, nil
}

func summarize(_ context.Context, req *sdk.GetPromptRequest) (*sdk.GetPromptResult, error) {
	return &sdk.GetPromptResult{Messages: []*sdk.PromptMessage{{
		Role:    "user",
		Content: &sdk.TextContent{Text: "Summarize " + req.Params.Arguments["topic"]},
	}}}, nil
}
