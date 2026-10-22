package mcp

import (
	"context"
	"encoding/json"

	sdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

// Resource is one MCP resource listing entry.
type Resource struct {
	URI         string
	Name        string
	Title       string
	Description string
	MIMEType    string
	Size        int64
}

// ResourceContent is one resource payload.
type ResourceContent struct {
	URI      string
	MIMEType string
	Text     string
	Blob     []byte
}

// Prompt is one MCP prompt listing entry.
type Prompt struct {
	Name        string
	Title       string
	Description string
	Arguments   []PromptArgument
}

// PromptArgument describes one prompt argument.
type PromptArgument struct {
	Name        string
	Title       string
	Description string
	Required    bool
}

// PromptMessage is one text prompt message.
type PromptMessage struct {
	Role string
	Text string
}

// ListResources returns every resource exposed by the session.
func ListResources(ctx context.Context, session *sdk.ClientSession) ([]Resource, error) {
	if session == nil {
		return nil, ErrSessionRequired
	}
	resources := []Resource{}
	cursor := ""
	for {
		result, err := session.ListResources(ctx, &sdk.ListResourcesParams{Cursor: cursor})
		if err != nil {
			return nil, err
		}
		for _, item := range result.Resources {
			resources = append(resources, Resource{
				URI:         item.URI,
				Name:        item.Name,
				Title:       item.Title,
				Description: item.Description,
				MIMEType:    item.MIMEType,
				Size:        item.Size,
			})
		}
		if result.NextCursor == "" {
			return resources, nil
		}
		cursor = result.NextCursor
	}
}

// ReadResource reads one resource by URI.
func ReadResource(ctx context.Context, session *sdk.ClientSession, uri string) ([]ResourceContent, error) {
	if session == nil {
		return nil, ErrSessionRequired
	}
	result, err := session.ReadResource(ctx, &sdk.ReadResourceParams{URI: uri})
	if err != nil {
		return nil, err
	}
	contents := make([]ResourceContent, 0, len(result.Contents))
	for _, item := range result.Contents {
		contents = append(contents, ResourceContent{
			URI:      item.URI,
			MIMEType: item.MIMEType,
			Text:     item.Text,
			Blob:     item.Blob,
		})
	}
	return contents, nil
}

// ListPrompts returns every prompt exposed by the session.
func ListPrompts(ctx context.Context, session *sdk.ClientSession) ([]Prompt, error) {
	if session == nil {
		return nil, ErrSessionRequired
	}
	prompts := []Prompt{}
	cursor := ""
	for {
		result, err := session.ListPrompts(ctx, &sdk.ListPromptsParams{Cursor: cursor})
		if err != nil {
			return nil, err
		}
		for _, item := range result.Prompts {
			arguments := make([]PromptArgument, 0, len(item.Arguments))
			for _, argument := range item.Arguments {
				arguments = append(arguments, PromptArgument{
					Name:        argument.Name,
					Title:       argument.Title,
					Description: argument.Description,
					Required:    argument.Required,
				})
			}
			prompts = append(prompts, Prompt{
				Name:        item.Name,
				Title:       item.Title,
				Description: item.Description,
				Arguments:   arguments,
			})
		}
		if result.NextCursor == "" {
			return prompts, nil
		}
		cursor = result.NextCursor
	}
}

// GetPrompt renders one prompt with arguments.
func GetPrompt(ctx context.Context, session *sdk.ClientSession, name string, arguments map[string]string) ([]PromptMessage, error) {
	if session == nil {
		return nil, ErrSessionRequired
	}
	result, err := session.GetPrompt(ctx, &sdk.GetPromptParams{
		Name:      name,
		Arguments: arguments,
	})
	if err != nil {
		return nil, err
	}
	messages := make([]PromptMessage, 0, len(result.Messages))
	for _, message := range result.Messages {
		messages = append(messages, PromptMessage{
			Role: string(message.Role),
			Text: promptText(message.Content),
		})
	}
	return messages, nil
}

func promptText(content sdk.Content) string {
	if text, ok := content.(*sdk.TextContent); ok {
		return text.Text
	}
	raw, err := json.Marshal(content)
	if err != nil {
		return ""
	}
	return string(raw)
}
