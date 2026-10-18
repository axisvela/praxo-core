// Package retriever defines document retrieval primitives.
package retriever

import "context"

// Document is a retrieved piece of context.
type Document struct {
	ID       string            `json:"id"`
	Content  string            `json:"content"`
	Metadata map[string]string `json:"metadata,omitempty"`
	Score    float64           `json:"score,omitempty"`
}

// Retriever returns documents relevant to a query.
type Retriever interface {
	Retrieve(ctx context.Context, query string, limit int) ([]Document, error)
}

// Func adapts a function to a Retriever.
type Func func(context.Context, string, int) ([]Document, error)

// Retrieve implements Retriever.
func (f Func) Retrieve(ctx context.Context, query string, limit int) ([]Document, error) {
	return f(ctx, query, limit)
}
