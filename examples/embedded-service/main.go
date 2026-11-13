package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type timeTool struct{}

func (timeTool) Name() string { return "get_time" }

func (timeTool) Description() string {
	return "Return the current local time in RFC3339 format."
}

func (timeTool) Spec() model.ToolSpec {
	return model.ToolSpec{
		Name:        "get_time",
		Description: "Return the current local time in RFC3339 format.",
		Parameters: map[string]any{
			"type":       "object",
			"properties": map[string]any{},
		},
	}
}

func (timeTool) Invoke(context.Context, map[string]any) (any, error) {
	return time.Now().Format(time.RFC3339), nil
}

type runRequest struct {
	Prompt string `json:"prompt"`
}

type runResponse struct {
	Output string `json:"output"`
}

func main() {
	addr := flag.String("addr", ":8080", "HTTP listen address")
	tenant := flag.String("tenant", "local", "application tenant ID")
	flag.Parse()

	baseURL := envOr("PRAXO_BASE_URL", "http://localhost:11434/v1")
	modelName := envOr("PRAXO_MODEL", "llama3.2")

	agentInstance, err := newAgent(openaicompat.Adapter{
		BaseURL: baseURL,
		APIKey:  os.Getenv("PRAXO_API_KEY"),
		Model:   modelName,
		HTTP:    &http.Client{Timeout: 120 * time.Second},
	})
	if err != nil {
		log.Fatal(err)
	}

	server := &http.Server{
		Addr:              *addr,
		Handler:           newHandler(agentInstance, *tenant),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      150 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		log.Printf("listening on %s (tenant %s)", *addr, *tenant)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatal(err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(ctx); err != nil {
		log.Fatal(err)
	}
}

func newAgent(runtimeModel model.Model) (*agent.Agent, error) {
	tools := tool.NewRegistry()
	tools.Register(timeTool{})

	return agent.New(agent.Options{
		Model:        runtimeModel,
		SystemPrompt: "You are a concise service assistant. Use tools when they help.",
		Tools:        tools,
		MaxSteps:     4,
		AllowedTools: []string{"get_time"},
		Events: event.FuncSink(func(_ context.Context, ev event.Event) error {
			log.Printf("event=%s", ev.Type)
			return nil
		}),
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			switch action.Kind {
			case "model.generate":
				return policy.Decision{Allowed: true}, nil
			case "tool.invoke":
				return policy.Decision{
					Allowed: action.ToolName == "get_time",
					Reason:  "only get_time is permitted",
				}, nil
			default:
				return policy.Decision{Reason: "unsupported action"}, nil
			}
		}),
	})
}

func newHandler(agentInstance *agent.Agent, tenant string) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("POST /run", func(w http.ResponseWriter, r *http.Request) {
		principal := r.Header.Get("X-Praxo-Principal")
		if principal == "" {
			writeError(w, http.StatusUnauthorized, "missing X-Praxo-Principal")
			return
		}
		var request runRequest
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10)).Decode(&request); err != nil {
			writeError(w, http.StatusBadRequest, "invalid JSON body")
			return
		}
		if request.Prompt == "" {
			writeError(w, http.StatusBadRequest, "prompt is required")
			return
		}
		result, err := agentInstance.Run(r.Context(), agent.Session{
			ID:          principal,
			TenantID:    tenant,
			WorkspaceID: "service",
		}, request.Prompt)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err.Error())
			return
		}
		writeJSON(w, http.StatusOK, runResponse{Output: result.Output})
	})
	return mux
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("write response: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
