package conformance

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/retriever"
)

// RetrieverCase is one retrieval expectation.
type RetrieverCase struct {
	// Name labels the case in errors. Empty names get an index label.
	Name string
	// Query is sent to Retrieve.
	Query string
	// Limit is sent to Retrieve. A positive limit also bounds the result count.
	Limit int
	// WantError requires Retrieve to return an error.
	WantError bool
	// WantDocumentID requires a document with this ID.
	WantDocumentID string
	// WantContentContains requires at least one document containing this text.
	WantContentContains string
}

// CheckRetriever verifies caller-supplied retrieval expectations.
func CheckRetriever(ctx context.Context, candidate retriever.Retriever, cases ...RetrieverCase) error {
	if candidate == nil {
		return errors.New("conformance: retriever is nil")
	}
	if len(cases) == 0 {
		return errors.New("conformance: at least one retriever case is required")
	}
	for i, tc := range cases {
		label := caseLabel(tc.Name, i)
		documents, err := candidate.Retrieve(ctx, tc.Query, tc.Limit)
		if tc.WantError {
			if err == nil {
				return fmt.Errorf("conformance: retriever %s: expected an error", label)
			}
			continue
		}
		if err != nil {
			return fmt.Errorf("conformance: retriever %s: %w", label, err)
		}
		if tc.Limit > 0 && len(documents) > tc.Limit {
			return fmt.Errorf("conformance: retriever %s: %d documents exceed limit %d", label, len(documents), tc.Limit)
		}
		if tc.WantDocumentID != "" && !hasDocument(documents, tc.WantDocumentID, "") {
			return fmt.Errorf("conformance: retriever %s: missing document %q", label, tc.WantDocumentID)
		}
		if tc.WantContentContains != "" && !hasDocument(documents, "", tc.WantContentContains) {
			return fmt.Errorf("conformance: retriever %s: no document contains %q", label, tc.WantContentContains)
		}
	}
	return nil
}

func hasDocument(documents []retriever.Document, id, content string) bool {
	for _, document := range documents {
		if id != "" && document.ID != id {
			continue
		}
		if content != "" && !strings.Contains(document.Content, content) {
			continue
		}
		return true
	}
	return false
}
