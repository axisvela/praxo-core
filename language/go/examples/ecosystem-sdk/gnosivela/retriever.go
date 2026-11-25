// Package gnosivela adapts the GNOSIVELA Go SDK to the PRAXO-CORE retrieval seam.
package gnosivela

import (
	"context"
	"errors"
	"fmt"
	"strconv"
	"strings"

	sdk "github.com/axisvela/GNOSIVELA-open/v3/sdk/go/gnosivela"
	"github.com/axisvela/praxo-core/v2/pkg/retriever"
)

// ErrClientRequired is returned when the SDK client is not configured.
var ErrClientRequired = errors.New("gnosivela: client is required")

// Retriever implements retriever.Retriever with GNOSIVELA grounding.
type Retriever struct {
	Client    *sdk.Client
	Principal string
	Purpose   string
	Budget    int
}

// Retrieve assembles a grounding bundle and maps it to documents.
func (r Retriever) Retrieve(ctx context.Context, query string, limit int) ([]retriever.Document, error) {
	if r.Client == nil {
		return nil, ErrClientRequired
	}
	budget := r.Budget
	if budget <= 0 {
		budget = limit * 200
		if budget <= 0 {
			budget = 1200
		}
	}
	bundle, err := r.Client.GroundingAssemble(ctx, query, r.Principal, r.Purpose, budget)
	if err != nil {
		return nil, err
	}
	documents := make([]retriever.Document, 0, len(bundle.Knowledge))
	for _, assertion := range bundle.Knowledge {
		documents = append(documents, retriever.Document{
			ID:      assertion.AssertionID,
			Content: assertionContent(assertion),
			Score:   assertion.Confidence,
			Metadata: map[string]string{
				"subject":   assertion.Subject.CanonicalID,
				"namespace": assertion.Subject.Namespace,
				"predicate": assertion.Predicate,
				"source":    assertion.Source,
				"status":    string(assertion.Status),
			},
		})
	}
	if limit > 0 && len(documents) > limit {
		documents = documents[:limit]
	}
	return documents, nil
}

func assertionContent(assertion *sdk.KnowledgeAssertion) string {
	value := valueString(assertion.Object)
	parts := []string{assertion.Subject.CanonicalID, assertion.Predicate}
	if value != "" {
		parts = append(parts, value)
	}
	return strings.TrimSpace(strings.Join(parts, " "))
}

func valueString(value sdk.Value) string {
	switch {
	case value.String != nil:
		return *value.String
	case value.Number != nil:
		return strconv.FormatFloat(*value.Number, 'g', -1, 64)
	case value.Boolean != nil:
		return strconv.FormatBool(*value.Boolean)
	case value.EntityRef != nil:
		return value.EntityRef.CanonicalID
	default:
		return fmt.Sprint(value)
	}
}
