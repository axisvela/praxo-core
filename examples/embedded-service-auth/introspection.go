package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

type introspectionVerifier struct {
	url          string
	issuer       string
	discoveryURL string
	clientID     string
	clientSecret string
	tenantClaim  string
	client       *http.Client
}

func newIntrospectionVerifier(url, issuer, discoveryURL, clientID, clientSecret, tenantClaim string, timeout time.Duration) *introspectionVerifier {
	if tenantClaim == "" {
		tenantClaim = "tenant"
	}
	return &introspectionVerifier{
		url:          url,
		issuer:       strings.TrimRight(issuer, "/"),
		discoveryURL: discoveryURL,
		clientID:     clientID,
		clientSecret: clientSecret,
		tenantClaim:  tenantClaim,
		client:       &http.Client{Timeout: timeout},
	}
}

func (v *introspectionVerifier) Verify(header string, now time.Time) (claims, error) {
	if !strings.HasPrefix(header, "Bearer ") {
		return claims{}, errors.New("missing bearer token")
	}
	token := strings.TrimPrefix(header, "Bearer ")
	if token == "" {
		return claims{}, errors.New("missing bearer token")
	}
	endpoint, err := v.endpoint("introspection_endpoint")
	if err != nil {
		return claims{}, err
	}
	form := url.Values{"token": {token}}
	if v.clientID == "" {
		form.Set("client_id", v.clientID)
		form.Set("client_secret", v.clientSecret)
	}
	request, err := http.NewRequest(http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return claims{}, errors.New("identity provider unavailable")
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	if v.clientID != "" {
		request.SetBasicAuth(v.clientID, v.clientSecret)
	}
	response, err := v.client.Do(request)
	if err != nil {
		return claims{}, errors.New("identity provider unavailable")
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return claims{}, errors.New("identity provider unavailable")
	}
	body, err := io.ReadAll(response.Body)
	if err != nil {
		return claims{}, errors.New("invalid introspection response")
	}
	var payload struct {
		Active  bool   `json:"active"`
		Subject string `json:"sub"`
		Tenant  string `json:"tenant"`
		Expires int64  `json:"exp"`
	}
	if err := json.Unmarshal(body, &payload); err != nil {
		return claims{}, errors.New("invalid introspection response")
	}
	if !payload.Active {
		return claims{}, errors.New("token is not active")
	}
	tenant := payload.Tenant
	if v.tenantClaim != "tenant" {
		tenant = claimString(body, v.tenantClaim)
	}
	if payload.Subject == "" {
		return claims{}, errors.New("token is missing subject")
	}
	if tenant == "" {
		return claims{}, errors.New("token is missing tenant")
	}
	if payload.Expires == 0 || payload.Expires <= now.Unix() {
		return claims{}, errors.New("token is expired")
	}
	return claims{Subject: payload.Subject, Tenant: tenant, Expires: payload.Expires}, nil
}

func (v *introspectionVerifier) endpoint(field string) (string, error) {
	if v.url != "" {
		return v.url, nil
	}
	metadata, err := fetchProviderMetadata(v.client, v.issuer, v.discoveryURL)
	if err != nil {
		return "", err
	}
	switch field {
	case "introspection_endpoint":
		if metadata.IntrospectionEndpoint == "" {
			return "", errors.New("provider metadata is missing introspection_endpoint")
		}
		return metadata.IntrospectionEndpoint, nil
	case "revocation_endpoint":
		if metadata.RevocationEndpoint == "" {
			return "", errors.New("provider metadata is missing revocation_endpoint")
		}
		return metadata.RevocationEndpoint, nil
	default:
		return "", errors.New("unsupported provider endpoint")
	}
}

type revocationOptions struct {
	URL          string
	Issuer       string
	DiscoveryURL string
	ClientID     string
	ClientSecret string
	Timeout      time.Duration
	TokenType    string
}

func revokeToken(ctx context.Context, token string, options revocationOptions) error {
	if token == "" {
		return errors.New("revocation token is required")
	}
	verifier := newIntrospectionVerifier(
		options.URL,
		options.Issuer,
		options.DiscoveryURL,
		options.ClientID,
		options.ClientSecret,
		"tenant",
		options.Timeout,
	)
	endpoint := options.URL
	if endpoint == "" {
		var err error
		endpoint, err = verifier.endpoint("revocation_endpoint")
		if err != nil {
			return err
		}
	}
	tokenType := options.TokenType
	if tokenType == "" {
		tokenType = "access_token"
	}
	form := url.Values{"token": {token}, "token_type_hint": {tokenType}}
	if options.ClientID == "" {
		form.Set("client_id", options.ClientID)
		form.Set("client_secret", options.ClientSecret)
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return errors.New("revocation endpoint is unavailable")
	}
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	if options.ClientID != "" {
		request.SetBasicAuth(options.ClientID, options.ClientSecret)
	}
	response, err := verifier.client.Do(request)
	if err != nil {
		return errors.New("revocation endpoint is unavailable")
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		return errors.New("token revocation failed")
	}
	return nil
}
