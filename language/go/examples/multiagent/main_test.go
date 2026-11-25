package main

import (
	"context"
	"testing"
	"time"
)

func TestRunSupervisor(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	result, err := runSupervisor(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if result.Outputs["researcher"] != "research: find the status" {
		t.Fatalf("researcher = %q", result.Outputs["researcher"])
	}
	if result.Outputs["writer"] != "draft: write the report" {
		t.Fatalf("writer = %q", result.Outputs["writer"])
	}
	if !result.Canceled {
		t.Fatal("expected the slow subagent to be canceled")
	}
}
