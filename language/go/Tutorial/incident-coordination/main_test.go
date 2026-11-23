package main

import (
	"context"
	"io"
	"testing"
)

func TestTutorialScenarios(t *testing.T) {
	if err := runTests(context.Background(), io.Discard); err != nil {
		t.Fatal(err)
	}
}
