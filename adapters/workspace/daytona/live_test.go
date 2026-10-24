package daytona

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/adapters/workspace/conformance"
)

func TestLiveConformance(t *testing.T) {
	apiKey := os.Getenv("DAYTONA_API_KEY")
	if apiKey == "" {
		t.Skip("DAYTONA_API_KEY is not set")
	}
	image := os.Getenv("DAYTONA_IMAGE")
	if image == "" {
		t.Skip("DAYTONA_IMAGE is not set")
	}
	provider, err := New(Config{
		APIKey:       apiKey,
		APIURL:       os.Getenv("DAYTONA_API_URL"),
		Target:       os.Getenv("DAYTONA_TARGET"),
		Organization: os.Getenv("DAYTONA_ORGANIZATION_ID"),
		DefaultImage: image,
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
