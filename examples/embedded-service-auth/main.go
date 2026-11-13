package main

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/axisvela/praxo-core/v2/adapters/openaicompat"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
	"github.com/axisvela/praxo-core/v2/pkg/event"
	"github.com/axisvela/praxo-core/v2/pkg/model"
	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
)

type claims struct {
	Subject string `json:"sub"`
	Tenant  string `json:"tenant"`
	Expires int64  `json:"exp"`
}

type runRequest struct {
	Prompt string `json:"prompt"`
}

type runResponse struct {
	Output string `json:"output"`
}

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

func main() {
	addr := flag.String("addr", ":8080", "HTTP listen address")
	flag.Parse()

	secret := os.Getenv("PRAXO_SERVICE_SECRET")
	if secret == "" {
		log.Fatal("PRAXO_SERVICE_SECRET is required")
	}
	allowed := parseTenants(envOr("PRAXO_ALLOWED_TENANTS", "local"))
	store, err := newFileStore(envOr("PRAXO_CHECKPOINT_DIR", "checkpoints"))
	if err != nil {
		log.Fatal(err)
	}
	agentInstance, err := newAgent(openaicompat.Adapter{
		BaseURL: envOr("PRAXO_BASE_URL", "http://localhost:11434/v1"),
		APIKey:  os.Getenv("PRAXO_API_KEY"),
		Model:   envOr("PRAXO_MODEL", "llama3.2"),
		HTTP:    &http.Client{Timeout: 120 * time.Second},
	}, allowed, store)
	if err != nil {
		log.Fatal(err)
	}
	server := &http.Server{
		Addr:              *addr,
		Handler:           newHandler(agentInstance, secret, allowed),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      150 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Printf("listening on %s", *addr)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func newAgent(runtimeModel model.Model, allowed map[string]bool, store *fileStore) (*agent.Agent, error) {
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
		Hooks: agent.Hooks{OnRunComplete: func(ctx context.Context, result *agent.Result) error {
			runContext := agent.RunContextFrom(ctx)
			sessionID, _ := runContext["session_id"].(string)
			tenant, _ := runContext["tenant_id"].(string)
			if store == nil || sessionID == "" {
				return nil
			}
			return store.Save(ctx, &checkpoint.Checkpoint{
				ID:          result.RunID,
				SessionID:   sessionID,
				RunID:       result.RunID,
				Status:      "completed",
				TenantID:    tenant,
				WorkspaceID: "service",
				Messages: []checkpoint.Message{{
					Role:    "assistant",
					Content: result.Output,
				}},
				CreatedAt: time.Now().UTC(),
			})
		}},
		Policy: policy.FuncHook(func(_ context.Context, action policy.Action) (policy.Decision, error) {
			tenant := tenantFromSession(action.SessionID)
			if !allowed[tenant] {
				return policy.Decision{Reason: "tenant is not allowed"}, nil
			}
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

func newHandler(agentInstance *agent.Agent, secret string, allowed map[string]bool) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("POST /run", func(w http.ResponseWriter, r *http.Request) {
		principal, err := verifyBearer(r.Header.Get("Authorization"), secret, time.Now())
		if err != nil {
			writeError(w, http.StatusUnauthorized, err.Error())
			return
		}
		if !allowed[principal.Tenant] {
			writeError(w, http.StatusForbidden, "tenant is not allowed")
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
		runContext := agent.WithRunContext(r.Context(), agent.RunContext{
			"session_id": principal.Tenant + "/" + principal.Subject,
			"tenant_id":  principal.Tenant,
		})
		result, err := agentInstance.Run(runContext, agent.Session{
			ID:          principal.Tenant + "/" + principal.Subject,
			TenantID:    principal.Tenant,
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

func verifyBearer(header, secret string, now time.Time) (claims, error) {
	if !strings.HasPrefix(header, "Bearer ") {
		return claims{}, errors.New("missing bearer token")
	}
	token := strings.TrimPrefix(header, "Bearer ")
	parts := strings.Split(token, ".")
	if len(parts) != 2 {
		return claims{}, errors.New("invalid token")
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return claims{}, errors.New("invalid token payload")
	}
	signature, err := hex.DecodeString(parts[1])
	if err != nil {
		return claims{}, errors.New("invalid token signature")
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(parts[0]))
	if !hmac.Equal(signature, mac.Sum(nil)) {
		return claims{}, errors.New("invalid token signature")
	}
	var verified claims
	if err := json.Unmarshal(payload, &verified); err != nil {
		return claims{}, errors.New("invalid token claims")
	}
	if verified.Subject == "" || verified.Tenant == "" {
		return claims{}, errors.New("token is missing subject or tenant")
	}
	if verified.Expires <= now.Unix() {
		return claims{}, errors.New("token is expired")
	}
	return verified, nil
}

func signToken(secret, subject, tenant string, expires time.Time) string {
	encoded, _ := json.Marshal(claims{
		Subject: subject,
		Tenant:  tenant,
		Expires: expires.Unix(),
	})
	payload := base64.RawURLEncoding.EncodeToString(encoded)
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(payload))
	return payload + "." + hex.EncodeToString(mac.Sum(nil))
}

func parseTenants(value string) map[string]bool {
	result := map[string]bool{}
	for _, item := range strings.Split(value, ",") {
		if tenant := strings.TrimSpace(item); tenant != "" {
			result[tenant] = true
		}
	}
	return result
}

func tenantFromSession(sessionID string) string {
	if index := strings.IndexByte(sessionID, '/'); index >= 0 {
		return sessionID[:index]
	}
	return sessionID
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
