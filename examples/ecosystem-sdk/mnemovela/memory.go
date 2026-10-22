// Package mnemovela adapts the Mnemovela Go SDK to the PRAXO-CORE memory seam.
package mnemovela

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"time"

	sdk "github.com/axisvela/mnemovela-open/sdk/go/v3/mnemovela"
	"github.com/axisvela/praxo-core/v2/pkg/memory"
)

// ErrClientRequired is returned when the SDK client is not configured.
var ErrClientRequired = errors.New("mnemovela: client is required")

// Store implements memory.Store with Mnemovela episodes and search.
type Store struct {
	Client *sdk.Client
	Branch string
}

// Put records one memory entry as an episode.
func (s Store) Put(ctx context.Context, sessionID string, record memory.Record) error {
	if s.Client == nil {
		return ErrClientRequired
	}
	params := sdk.P{
		"branch_name": s.branch(sessionID),
		"content":     record.Content,
		"metadata": map[string]any{
			"record_id":  record.ID,
			"frame":      string(record.Frame),
			"created_at": record.CreatedAt,
			"metadata":   record.Metadata,
		},
	}
	_, err := s.Client.AddEpisode(ctx, params)
	return err
}

// Search returns memory records relevant to the query.
func (s Store) Search(ctx context.Context, sessionID, query string, limit int) ([]memory.Record, error) {
	if s.Client == nil {
		return nil, ErrClientRequired
	}
	if limit <= 0 {
		limit = 8
	}
	raw, err := s.Client.SearchMemory(ctx, sdk.P{
		"query":       query,
		"branch_name": s.branch(sessionID),
		"top_k":       limit,
	})
	if err != nil {
		return nil, err
	}
	var items []searchItem
	if err := json.Unmarshal(raw, &items); err != nil {
		return nil, err
	}
	records := make([]memory.Record, 0, len(items))
	for _, item := range items {
		records = append(records, item.record())
	}
	return records, nil
}

func (s Store) branch(sessionID string) string {
	if s.Branch != "" {
		return s.Branch
	}
	return sessionID
}

type searchItem struct {
	CommitID string          `json:"commit_id"`
	Score    float64         `json:"score"`
	Frame    json.RawMessage `json:"frame"`
}

func (item searchItem) record() memory.Record {
	frame := item.Frame
	var fields map[string]any
	_ = json.Unmarshal(frame, &fields)
	record := memory.Record{
		ID:      item.CommitID,
		Frame:   memory.FrameEvent,
		Content: string(frame),
		Metadata: map[string]any{
			"score":     item.Score,
			"commit_id": item.CommitID,
			"frame":     string(frame),
		},
	}
	if kind, ok := fields["memory_type"].(string); ok && kind != "" {
		record.Frame = memory.Frame(kind)
	}
	switch kind := record.Frame; kind {
	case memory.FrameDecision:
		record.Content = firstString(fields, "decision_summary", "summary", "what", "content")
	case memory.FrameConstraint:
		record.Content = firstString(fields, "constraint_summary", "summary", "what", "content")
	case memory.FrameEvent:
		record.Content = firstString(fields, "what", "summary", "content")
	default:
		record.Content = firstString(fields, "summary", "what", "content")
	}
	if record.Content == "" {
		record.Content = string(frame)
	}
	if stamp, ok := fields["created_at"].(string); ok {
		if parsed, err := time.Parse(time.RFC3339, stamp); err == nil {
			record.CreatedAt = parsed
		}
	}
	return record
}

func firstString(fields map[string]any, keys ...string) string {
	for _, key := range keys {
		if value, ok := fields[key].(string); ok && strings.TrimSpace(value) != "" {
			return value
		}
	}
	return ""
}
