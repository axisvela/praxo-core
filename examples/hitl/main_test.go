package main

import (
	"bytes"
	"context"
	"testing"
)

func TestApproveAndEditScenarios(t *testing.T) {
	var out bytes.Buffer
	if err := run(context.Background(), &out); err != nil {
		t.Fatal(err)
	}
	want := "approve: written; effects=1\nedit: policy rejected; effects=0\n"
	if out.String() != want {
		t.Fatalf("output=%q want %q", out.String(), want)
	}
}
