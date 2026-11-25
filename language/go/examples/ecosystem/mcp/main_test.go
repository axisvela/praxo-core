package main

import (
	"context"
	"testing"
)

func TestRun(t *testing.T) {
	summary, err := run(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(summary.Resources) != 1 || summary.Resources[0].URI != "demo:status" {
		t.Fatalf("resources = %#v", summary.Resources)
	}
	if len(summary.Contents) != 1 || summary.Contents[0].Text != "status: green" {
		t.Fatalf("contents = %#v", summary.Contents)
	}
	if len(summary.Prompts) != 1 || summary.Prompts[0].Name != "summarize" {
		t.Fatalf("prompts = %#v", summary.Prompts)
	}
	if len(summary.Prompts[0].Arguments) != 1 || !summary.Prompts[0].Arguments[0].Required {
		t.Fatalf("arguments = %#v", summary.Prompts[0].Arguments)
	}
	if len(summary.Messages) != 1 || summary.Messages[0].Text != "Summarize release" {
		t.Fatalf("messages = %#v", summary.Messages)
	}
}
