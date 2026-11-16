package main

import (
	"crypto"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"
)

var oidcAlgorithms = map[string]crypto.Hash{
	"RS256": crypto.SHA256,
	"RS384": crypto.SHA384,
	"RS512": crypto.SHA512,
}

type jwkKey struct {
	KID string `json:"kid"`
	KTY string `json:"kty"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type jwksDocument struct {
	Keys []jwkKey `json:"keys"`
}

type providerMetadata struct {
	Issuer  string `json:"issuer"`
	JWKSURI string `json:"jwks_uri"`
}

type oidcVerifier struct {
	issuer       string
	audience     string
	jwksURL      string
	discoveryURL string
	tenantClaim  string
	client       *http.Client

	mu       sync.Mutex
	keys     map[string]jwkKey
	fetched  time.Time
	cacheTTL time.Duration
}

func newOIDCVerifier(issuer, audience, jwksURL, discoveryURL, tenantClaim string, timeout time.Duration) *oidcVerifier {
	if tenantClaim == "" {
		tenantClaim = "tenant"
	}
	return &oidcVerifier{
		issuer:       strings.TrimRight(issuer, "/"),
		audience:     audience,
		jwksURL:      jwksURL,
		discoveryURL: discoveryURL,
		tenantClaim:  tenantClaim,
		client:       &http.Client{Timeout: timeout},
		cacheTTL:     5 * time.Minute,
	}
}

func (v *oidcVerifier) Verify(header string, now time.Time) (claims, error) {
	if !strings.HasPrefix(header, "Bearer ") {
		return claims{}, errors.New("missing bearer token")
	}
	token := strings.TrimPrefix(header, "Bearer ")
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return claims{}, errors.New("invalid token")
	}
	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return claims{}, errors.New("invalid token header")
	}
	var tokenHeader struct {
		Algorithm string `json:"alg"`
		KID       string `json:"kid"`
	}
	if err := json.Unmarshal(headerBytes, &tokenHeader); err != nil {
		return claims{}, errors.New("invalid token header")
	}
	hash, ok := oidcAlgorithms[tokenHeader.Algorithm]
	if !ok {
		return claims{}, errors.New("unsupported token algorithm")
	}
	if tokenHeader.KID == "" {
		return claims{}, errors.New("token is missing key id")
	}
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return claims{}, errors.New("invalid token claims")
	}
	var payload struct {
		Issuer    string          `json:"iss"`
		Audience  json.RawMessage `json:"aud"`
		Subject   string          `json:"sub"`
		Tenant    string          `json:"tenant"`
		Expires   int64           `json:"exp"`
		NotBefore int64           `json:"nbf"`
	}
	if err := json.Unmarshal(payloadBytes, &payload); err != nil {
		return claims{}, errors.New("invalid token claims")
	}
	if payload.Issuer != v.issuer {
		return claims{}, errors.New("invalid token issuer")
	}
	if !audienceMatches(payload.Audience, v.audience) {
		return claims{}, errors.New("invalid token audience")
	}
	if payload.Expires == 0 || payload.Expires <= now.Unix() {
		return claims{}, errors.New("token is expired")
	}
	if payload.NotBefore != 0 && payload.NotBefore > now.Unix() {
		return claims{}, errors.New("token is not active")
	}
	tenant := payload.Tenant
	if v.tenantClaim != "tenant" {
		tenant = claimString(payloadBytes, v.tenantClaim)
	}
	if payload.Subject == "" {
		return claims{}, errors.New("token is missing subject")
	}
	if tenant == "" {
		return claims{}, errors.New("token is missing tenant")
	}
	signature, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return claims{}, errors.New("invalid token signature")
	}
	key, err := v.key(tokenHeader.KID, tokenHeader.Algorithm, false)
	if err != nil {
		return claims{}, err
	}
	if key.KID == "" {
		key, err = v.key(tokenHeader.KID, tokenHeader.Algorithm, true)
		if err != nil {
			return claims{}, err
		}
	}
	if key.KID == "" {
		return claims{}, errors.New("unknown token key")
	}
	publicKey, err := rsaPublicKey(key)
	if err != nil {
		return claims{}, err
	}
	digest := hash.New()
	digest.Write([]byte(parts[0] + "." + parts[1]))
	if err := rsa.VerifyPKCS1v15(publicKey, hash, digest.Sum(nil), signature); err != nil {
		return claims{}, errors.New("invalid token signature")
	}
	return claims{Subject: payload.Subject, Tenant: tenant, Expires: payload.Expires}, nil
}

func (v *oidcVerifier) key(kid, algorithm string, refresh bool) (jwkKey, error) {
	v.mu.Lock()
	defer v.mu.Unlock()
	if refresh || v.keys == nil || time.Since(v.fetched) > v.cacheTTL {
		keys, err := v.fetchKeys()
		if err != nil {
			return jwkKey{}, err
		}
		v.keys = keys
		v.fetched = time.Now()
	}
	key := v.keys[kid]
	if key.KID == "" || key.KTY != "RSA" {
		return jwkKey{}, nil
	}
	if key.Use != "" && key.Use != "sig" {
		return jwkKey{}, nil
	}
	if key.Alg != "" && key.Alg != algorithm {
		return jwkKey{}, nil
	}
	return key, nil
}

func (v *oidcVerifier) fetchKeys() (map[string]jwkKey, error) {
	jwksURL := v.jwksURL
	if jwksURL == "" {
		metadata, err := v.metadata()
		if err != nil {
			return nil, err
		}
		jwksURL = metadata.JWKSURI
	}
	if jwksURL == "" {
		return nil, errors.New("identity provider JWKS is not configured")
	}
	response, err := v.client.Get(jwksURL)
	if err != nil {
		return nil, errors.New("identity provider unavailable")
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return nil, errors.New("identity provider unavailable")
	}
	var document jwksDocument
	if err := json.NewDecoder(response.Body).Decode(&document); err != nil {
		return nil, errors.New("invalid JWKS")
	}
	keys := map[string]jwkKey{}
	for _, key := range document.Keys {
		if key.KID != "" {
			keys[key.KID] = key
		}
	}
	return keys, nil
}

func (v *oidcVerifier) metadata() (providerMetadata, error) {
	if v.issuer == "" {
		return providerMetadata{}, errors.New("identity provider issuer is required")
	}
	url := v.discoveryURL
	if url == "" {
		url = v.issuer + "/.well-known/openid-configuration"
	}
	response, err := v.client.Get(url)
	if err != nil {
		return providerMetadata{}, errors.New("identity provider unavailable")
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return providerMetadata{}, errors.New("identity provider unavailable")
	}
	var metadata providerMetadata
	if err := json.NewDecoder(response.Body).Decode(&metadata); err != nil {
		return providerMetadata{}, errors.New("invalid provider metadata")
	}
	if strings.TrimRight(metadata.Issuer, "/") != v.issuer {
		return providerMetadata{}, errors.New("invalid provider issuer")
	}
	if metadata.JWKSURI == "" {
		return providerMetadata{}, errors.New("provider metadata is missing jwks_uri")
	}
	return metadata, nil
}

func rsaPublicKey(key jwkKey) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(key.N)
	if err != nil || len(nBytes) == 0 {
		return nil, errors.New("invalid token key")
	}
	eBytes, err := base64.RawURLEncoding.DecodeString(key.E)
	if err != nil || len(eBytes) == 0 || len(eBytes) > 4 {
		return nil, errors.New("invalid token key")
	}
	exponent := 0
	for _, value := range eBytes {
		exponent = exponent<<8 | int(value)
	}
	if exponent < 3 {
		return nil, errors.New("invalid token key")
	}
	return &rsa.PublicKey{N: new(big.Int).SetBytes(nBytes), E: exponent}, nil
}

func audienceMatches(raw json.RawMessage, expected string) bool {
	if len(raw) == 0 {
		return false
	}
	var value string
	if err := json.Unmarshal(raw, &value); err == nil {
		return value == expected
	}
	var values []string
	if err := json.Unmarshal(raw, &values); err != nil {
		return false
	}
	for _, candidate := range values {
		if candidate == expected {
			return true
		}
	}
	return false
}

func claimString(payload []byte, name string) string {
	var values map[string]any
	if err := json.Unmarshal(payload, &values); err != nil {
		return ""
	}
	value, _ := values[name].(string)
	return value
}
