package mnemovela

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	sdk "github.com/axisvela/mnemovela-open/sdk/go/v3/mnemovela"
	"github.com/axisvela/mnemovela-open/sdk/go/v3/mnemovela/transport/jsonrpc"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
)

var _ memory.Store = Store{}

func TestStoreRequiresClient(t *testing.T) {
	ctx := context.Background()
	if err := (Store{}).Put(ctx, "s", memory.Record{}); !errors.Is(err, ErrClientRequired) {
		t.Fatalf("got %v, want %v", err, ErrClientRequired)
	}
	if _, err := (Store{}).Search(ctx, "s", "q", 1); !errors.Is(err, ErrClientRequired) {
		t.Fatalf("got %v, want %v", err, ErrClientRequired)
	}
}

func TestStoreUsesJSONRPC(t *testing.T) {
	var methods []string
	var episode, search map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var request struct {
			Method string         `json:"method"`
			Params map[string]any `json:"params"`
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		methods = append(methods, request.Method)
		var result any
		switch request.Method {
		case "mnemovela.add_episode":
			episode = request.Params
			result = map[string]any{"commit_id": "commit-1"}
		case "mnemovela.search_memory":
			search = request.Params
			result = []map[string]any{{
				"commit_id": "commit-1",
				"score":     0.92,
				"frame": map[string]any{
					"memory_type": "event",
					"what":        "status is green",
					"created_at":  "2026-10-22T00:00:00Z",
				},
			}}
		default:
			http.Error(w, "unexpected method", http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"jsonrpc": "2.0",
			"id":      1,
			"result":  result,
		})
	}))
	defer server.Close()

	client := sdk.New(jsonrpc.New(server.URL))
	store := Store{Client: client}
	ctx := context.Background()

	if err := store.Put(ctx, "session-1", memory.Record{
		ID:      "record-1",
		Frame:   memory.FrameEvent,
		Content: "status is green",
	}); err != nil {
		t.Fatal(err)
	}
	if episode["branch_name"] != "session-1" || episode["content"] != "status is green" {
		t.Fatalf("episode params = %#v", episode)
	}

	records, err := store.Search(ctx, "session-1", "status", 5)
	if err != nil {
		t.Fatal(err)
	}
	if search["branch_name"] != "session-1" || search["query"] != "status" || search["top_k"] != float64(5) {
		t.Fatalf("search params = %#v", search)
	}
	if len(records) != 1 {
		t.Fatalf("records = %#v", records)
	}
	record := records[0]
	if record.ID != "commit-1" || record.Frame != memory.FrameEvent || record.Content != "status is green" {
		t.Fatalf("record = %#v", record)
	}
	if record.CreatedAt.IsZero() {
		t.Fatal("expected created_at to be parsed")
	}
	if len(methods) != 2 {
		t.Fatalf("methods = %#v", methods)
	}
}
