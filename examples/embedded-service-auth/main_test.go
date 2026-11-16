package main

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

const testSecret = "test-secret"

type fakeModel struct{}

func (fakeModel) Generate(context.Context, model.Request) (model.Response, error) {
	return model.Response{
		Message: model.Message{
			Role:    model.RoleAssistant,
			Content: "hello from the authenticated service",
		},
	}, nil
}

func testHandler(t *testing.T) (http.Handler, *fileStore) {
	t.Helper()
	return testHandlerWithAuth(t, func(header string, now time.Time) (claims, error) {
		return verifyBearer(header, testSecret, now)
	})
}

func testHandlerWithAuth(t *testing.T, authenticate func(string, time.Time) (claims, error)) (http.Handler, *fileStore) {
	t.Helper()
	store, err := newFileStore(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	agentInstance, err := newAgent(fakeModel{}, map[string]bool{"local": true}, store)
	if err != nil {
		t.Fatal(err)
	}
	return newHandler(agentInstance, authenticate, map[string]bool{"local": true}), store
}

func newRunRequest(token string) *http.Request {
	request := httptest.NewRequest(http.MethodPost, "/run", strings.NewReader(`{"prompt":"hi"}`))
	request.Header.Set("Content-Type", "application/json")
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	return request
}

func TestRequiresBearerToken(t *testing.T) {
	handler, _ := testHandler(t)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, newRunRequest(""))
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", response.Code)
	}
}

func TestRejectsExpiredToken(t *testing.T) {
	token := signToken(testSecret, "user-1", "local", time.Now().Add(-time.Minute))
	handler, _ := testHandler(t)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, newRunRequest(token))
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", response.Code)
	}
}

func TestRejectsUnknownTenant(t *testing.T) {
	token := signToken(testSecret, "user-1", "other", time.Now().Add(time.Hour))
	handler, _ := testHandler(t)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, newRunRequest(token))
	if response.Code != http.StatusForbidden {
		t.Fatalf("expected 403, got %d", response.Code)
	}
}

func TestReturnsOutputForVerifiedTenant(t *testing.T) {
	token := signToken(testSecret, "user-1", "local", time.Now().Add(time.Hour))
	handler, store := testHandler(t)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, newRunRequest(token))
	if response.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", response.Code, response.Body.String())
	}
	var body runResponse
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body.Output != "hello from the authenticated service" {
		t.Fatalf("unexpected output: %q", body.Output)
	}
	loaded, err := store.Load(context.Background(), "local/user-1")
	if err != nil {
		t.Fatal(err)
	}
	if loaded == nil || loaded.Status != "completed" || len(loaded.Messages) != 1 {
		t.Fatalf("checkpoint was not persisted: %#v", loaded)
	}
}

const oidcIssuer = "https://issuer.example.com"
const oidcAudience = "praxo-service"
const oidcKeyID = "test-key"

func newTestKey(t *testing.T) *rsa.PrivateKey {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatal(err)
	}
	return key
}

func jwksDocumentFor(key *rsa.PrivateKey) map[string]any {
	return map[string]any{
		"keys": []map[string]any{{
			"kty": "RSA",
			"kid": oidcKeyID,
			"use": "sig",
			"alg": "RS256",
			"n":   base64.RawURLEncoding.EncodeToString(key.PublicKey.N.Bytes()),
			"e":   base64.RawURLEncoding.EncodeToString(big.NewInt(int64(key.PublicKey.E)).Bytes()),
		}},
	}
}

func signJWT(t *testing.T, key *rsa.PrivateKey, kid string, values map[string]any) string {
	t.Helper()
	header, err := json.Marshal(map[string]any{"alg": "RS256", "typ": "JWT", "kid": kid})
	if err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(values)
	if err != nil {
		t.Fatal(err)
	}
	signingInput := base64.RawURLEncoding.EncodeToString(header) + "." + base64.RawURLEncoding.EncodeToString(payload)
	digest := sha256.Sum256([]byte(signingInput))
	signature, err := rsa.SignPKCS1v15(rand.Reader, key, crypto.SHA256, digest[:])
	if err != nil {
		t.Fatal(err)
	}
	return signingInput + "." + base64.RawURLEncoding.EncodeToString(signature)
}

func oidcClaims() map[string]any {
	return map[string]any{
		"iss":    oidcIssuer,
		"aud":    oidcAudience,
		"sub":    "user-1",
		"tenant": "local",
		"exp":    time.Now().Add(time.Hour).Unix(),
	}
}

func withOIDCProvider(t *testing.T, key *rsa.PrivateKey, run func(discoveryURL string)) {
	t.Helper()
	mux := http.NewServeMux()
	var server *httptest.Server
	mux.HandleFunc("/.well-known/openid-configuration", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{
			"issuer":   oidcIssuer,
			"jwks_uri": server.URL + "/jwks",
		})
	})
	mux.HandleFunc("/jwks", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, jwksDocumentFor(key))
	})
	server = httptest.NewServer(mux)
	defer server.Close()
	run(server.URL + "/.well-known/openid-configuration")
}

func oidcHandler(t *testing.T, discoveryURL string) http.Handler {
	t.Helper()
	verifier := newOIDCVerifier(
		oidcIssuer,
		oidcAudience,
		"",
		discoveryURL,
		"tenant",
		2*time.Second,
	)
	handler, _ := testHandlerWithAuth(t, verifier.Verify)
	return handler
}

func TestOIDCDiscoveryVerifiesToken(t *testing.T) {
	key := newTestKey(t)
	withOIDCProvider(t, key, func(discoveryURL string) {
		handler := oidcHandler(t, discoveryURL)
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, newRunRequest(signJWT(t, key, oidcKeyID, oidcClaims())))
		if response.Code != http.StatusOK {
			t.Fatalf("expected 200, got %d: %s", response.Code, response.Body.String())
		}
	})
}

func TestOIDCRejectsWrongAudience(t *testing.T) {
	key := newTestKey(t)
	withOIDCProvider(t, key, func(discoveryURL string) {
		handler := oidcHandler(t, discoveryURL)
		values := oidcClaims()
		values["aud"] = "other-service"
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, newRunRequest(signJWT(t, key, oidcKeyID, values)))
		if response.Code != http.StatusUnauthorized {
			t.Fatalf("expected 401, got %d", response.Code)
		}
	})
}

func TestOIDCRejectsExpiredToken(t *testing.T) {
	key := newTestKey(t)
	withOIDCProvider(t, key, func(discoveryURL string) {
		handler := oidcHandler(t, discoveryURL)
		values := oidcClaims()
		values["exp"] = time.Now().Add(-time.Minute).Unix()
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, newRunRequest(signJWT(t, key, oidcKeyID, values)))
		if response.Code != http.StatusUnauthorized {
			t.Fatalf("expected 401, got %d", response.Code)
		}
	})
}

func TestOIDCRejectsUnknownKey(t *testing.T) {
	key := newTestKey(t)
	withOIDCProvider(t, key, func(discoveryURL string) {
		handler := oidcHandler(t, discoveryURL)
		response := httptest.NewRecorder()
		handler.ServeHTTP(response, newRunRequest(signJWT(t, key, "other-key", oidcClaims())))
		if response.Code != http.StatusUnauthorized {
			t.Fatalf("expected 401, got %d", response.Code)
		}
	})
}

func TestOIDCProviderUnavailableFailsClosed(t *testing.T) {
	key := newTestKey(t)
	server := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {}))
	discoveryURL := server.URL + "/.well-known/openid-configuration"
	server.Close()
	handler := oidcHandler(t, discoveryURL)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, newRunRequest(signJWT(t, key, oidcKeyID, oidcClaims())))
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected 401, got %d", response.Code)
	}
}
