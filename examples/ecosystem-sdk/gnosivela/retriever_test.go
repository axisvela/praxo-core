package gnosivela

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	sdk "github.com/axisvela/GNOSIVELA-open/v3/sdk/go/gnosivela"
	"github.com/axisvela/praxo-core/v2/pkg/retriever"
)

var _ retriever.Retriever = Retriever{}

func TestRetrieverRequiresClient(t *testing.T) {
	if _, err := (Retriever{}).Retrieve(context.Background(), "q", 1); !errors.Is(err, ErrClientRequired) {
		t.Fatalf("got %v, want %v", err, ErrClientRequired)
	}
}

func TestRetrieverUsesGrounding(t *testing.T) {
	var request map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/grounding/assemble" {
			http.NotFound(w, r)
			return
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{
			"resolvedIntent": "status",
			"knowledge": [{
				"assertionId": "assertion-1",
				"subject": {"namespace": "acme", "canonicalId": "account:acme"},
				"predicate": "status",
				"object": {"type": "string", "string": "green"},
				"context": {},
				"recordedAt": "2026-10-22T00:00:00Z",
				"source": "erp",
				"confidence": 0.9,
				"status": "ASSERTED"
			}]
		}`))
	}))
	defer server.Close()

	adapter := Retriever{
		Client:    sdk.New(server.URL),
		Principal: "user:demo",
		Purpose:   "status_lookup",
		Budget:    1200,
	}
	documents, err := adapter.Retrieve(context.Background(), "status", 10)
	if err != nil {
		t.Fatal(err)
	}
	if request["query"] != "status" || request["principal"] != "user:demo" || request["purpose"] != "status_lookup" {
		t.Fatalf("request = %#v", request)
	}
	if request["budget"] != float64(1200) {
		t.Fatalf("budget = %#v", request["budget"])
	}
	if len(documents) != 1 {
		t.Fatalf("documents = %#v", documents)
	}
	document := documents[0]
	if document.ID != "assertion-1" || document.Content != "account:acme status green" {
		t.Fatalf("document = %#v", document)
	}
	if document.Score != 0.9 || document.Metadata["source"] != "erp" || document.Metadata["status"] != "ASSERTED" {
		t.Fatalf("document = %#v", document)
	}
}
