package longrunning

import (
	"encoding/json"
	"net/http"
)

func NewVerifierHandler(secret, token string) http.Handler {
	return NewVerifierHandlerWithSecrets(StaticSecret(secret), StaticSecret(token))
}

func NewVerifierHandlerWithSecrets(secret, token SecretSource) http.Handler {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost || r.URL.Path != "/verify" {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		value, err := secret.Value()
		if err != nil {
			http.Error(w, "verifier unavailable", http.StatusInternalServerError)
			return
		}
		var request struct {
			OperationID string `json:"operation_id"`
			Evidence    string `json:"evidence"`
			Receipt     string `json:"receipt"`
		}
		if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
			http.Error(w, "invalid request", http.StatusBadRequest)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"valid": newEffectVerifier(value).valid(request.OperationID, request.Evidence, request.Receipt),
		})
	})
	return requireBearerSource(handler, token)
}
