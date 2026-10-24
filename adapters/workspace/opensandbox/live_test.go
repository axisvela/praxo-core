package opensandbox

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/adapters/workspace/conformance"
)

func TestLiveConformance(t *testing.T) {
	domain := os.Getenv("OPEN_SANDBOX_DOMAIN")
	image := os.Getenv("OPEN_SANDBOX_IMAGE")
	if domain == "" || image == "" {
		t.Skip("OPEN_SANDBOX_DOMAIN and OPEN_SANDBOX_IMAGE are not set")
	}
	provider := New(Config{
		Domain:       domain,
		Protocol:     os.Getenv("OPEN_SANDBOX_PROTOCOL"),
		APIKey:       os.Getenv("OPEN_SANDBOX_API_KEY"),
		DefaultImage: image,
	})
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
