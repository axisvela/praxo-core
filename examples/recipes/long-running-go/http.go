package longrunning

import (
	"encoding/json"
	"net/http"
	"os"
	"strings"
)

func NewHandler(statePath, token, verifierSecret string) http.Handler {
	service := newRemoteOperationsWithVerifier(statePath, newEffectVerifier(verifierSecret))
	if stage := os.Getenv("PRAXO_CRASH_AT"); stage != "" {
		service.commitHook = func(current string) error {
			if current == stage {
				os.Exit(42)
			}
			return nil
		}
	}
	return requireBearer(longRunningHandler(service), token)
}

func requireBearer(next http.Handler, token string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer "+token {
			w.Header().Set("WWW-Authenticate", `Bearer realm="operations"`)
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func longRunningHandler(service *remoteOperations) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/operations", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var request struct {
			Key string `json:"key"`
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil || request.Key == "" {
			http.Error(w, "invalid request", http.StatusBadRequest)
			return
		}
		op, created := service.submit(request.Key)
		if r.Header.Get("X-Fail-After-Commit") == "1" {
			http.Error(w, "simulated response loss", http.StatusInternalServerError)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"id": op.ID, "state": op.State, "created": created,
		})
	})
	mux.HandleFunc("/operations/", func(w http.ResponseWriter, r *http.Request) {
		parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/operations/"), "/")
		id := parts[0]
		if len(parts) == 1 {
			if r.Method != http.MethodGet {
				w.WriteHeader(http.StatusMethodNotAllowed)
				return
			}
			op, ok := service.status(id)
			if !ok {
				http.Error(w, "operation not found", http.StatusNotFound)
				return
			}
			writeJSON(w, http.StatusOK, op)
			return
		}
		if r.Method != http.MethodPost {
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var op remoteOperation
		var ok bool
		switch parts[1] {
		case "cancel-request":
			op, ok = service.requestCancel(id)
		case "cancel-confirm":
			op, ok = service.confirmCancel(id)
		case "complete":
			op, ok = service.complete(id)
		case "verify-effect":
			var request struct {
				Evidence string `json:"evidence"`
				Receipt  string `json:"receipt"`
			}
			if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
				http.Error(w, "invalid request", http.StatusBadRequest)
				return
			}
			op, ok = service.verifyEffect(id, request.Evidence, request.Receipt)
		default:
			http.Error(w, "unknown action", http.StatusNotFound)
			return
		}
		if !ok {
			http.Error(w, "operation not found or invalid state", http.StatusConflict)
			return
		}
		writeJSON(w, http.StatusOK, op)
	})
	return mux
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
