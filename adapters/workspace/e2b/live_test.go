package e2b

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/adapters/workspace/conformance"
)

func TestLiveConformance(t *testing.T) {
	apiKey := os.Getenv("E2B_API_KEY")
	if apiKey == "" {
		t.Skip("E2B_API_KEY is not set")
	}
	provider, err := New(Config{
		APIKey:          apiKey,
		PlatformURL:     os.Getenv("E2B_PLATFORM_URL"),
		EnvdURL:         os.Getenv("E2B_ENVD_URL"),
		DefaultTemplate: envOr("E2B_TEMPLATE", "base"),
	})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	defer cancel()
	if err := conformance.CheckProvider(ctx, provider, conformance.Case{
		Command:            []string{"echo", "ok"},
		WantStdoutContains: "echo ok",
		Path:               "praxo-conformance/file.txt",
		Content:            []byte("conformance"),
	}); err != nil {
		t.Fatal(err)
	}
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
