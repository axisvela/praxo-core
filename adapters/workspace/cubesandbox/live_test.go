package cubesandbox

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/adapters/workspace/conformance"
)

func TestLiveConformance(t *testing.T) {
	apiURL := os.Getenv("CUBE_API_URL")
	templateID := os.Getenv("CUBE_TEMPLATE_ID")
	if apiURL == "" || templateID == "" {
		t.Skip("CUBE_API_URL and CUBE_TEMPLATE_ID are not set")
	}
	provider := New(Config{
		APIURL:     apiURL,
		APIKey:     os.Getenv("CUBE_API_KEY"),
		TemplateID: templateID,
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
