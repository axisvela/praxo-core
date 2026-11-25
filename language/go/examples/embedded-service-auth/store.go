package main

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"

	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
)

type fileStore struct {
	root string
}

func newFileStore(root string) (*fileStore, error) {
	if err := os.MkdirAll(root, 0o700); err != nil {
		return nil, err
	}
	return &fileStore{root: root}, nil
}

func (s *fileStore) sessionDir(sessionID string) string {
	return filepath.Join(s.root, "sessions", hex.EncodeToString([]byte(sessionID)))
}

func (s *fileStore) Save(_ context.Context, cp *checkpoint.Checkpoint) error {
	if cp == nil || cp.ID == "" || cp.SessionID == "" || cp.RunID == "" {
		return errors.New("checkpoint needs id, session id, and run id")
	}
	directory := s.sessionDir(cp.SessionID)
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return err
	}
	encoded, err := json.Marshal(cp)
	if err != nil {
		return err
	}
	final := filepath.Join(directory, hex.EncodeToString([]byte(cp.ID))+".json")
	temporary := final + ".tmp"
	if err := os.WriteFile(temporary, encoded, 0o600); err != nil {
		return err
	}
	return os.Rename(temporary, final)
}

func (s *fileStore) Load(ctx context.Context, sessionID string) (*checkpoint.Checkpoint, error) {
	items, err := s.List(ctx, sessionID)
	if err != nil || len(items) == 0 {
		return nil, err
	}
	return &items[0], nil
}

func (s *fileStore) LoadScoped(ctx context.Context, tenantID, sessionID string) (*checkpoint.Checkpoint, error) {
	items, err := s.List(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	for i := range items {
		if tenantID == "" || items[i].TenantID == tenantID {
			return &items[i], nil
		}
	}
	return nil, nil
}

func (s *fileStore) LoadRun(ctx context.Context, runID string) (*checkpoint.Checkpoint, error) {
	return s.LoadRunScoped(ctx, "", runID)
}

func (s *fileStore) LoadRunScoped(ctx context.Context, tenantID, runID string) (*checkpoint.Checkpoint, error) {
	sessions, err := s.sessions()
	if err != nil {
		return nil, err
	}
	var best *checkpoint.Checkpoint
	for _, sessionID := range sessions {
		items, err := s.List(ctx, sessionID)
		if err != nil {
			return nil, err
		}
		for i := range items {
			item := &items[i]
			if item.RunID != runID || (tenantID != "" && item.TenantID != tenantID) {
				continue
			}
			if best == nil || item.CreatedAt.After(best.CreatedAt) {
				copy := *item
				best = &copy
			}
		}
	}
	return best, nil
}

func (s *fileStore) List(_ context.Context, sessionID string) ([]checkpoint.Checkpoint, error) {
	entries, err := os.ReadDir(s.sessionDir(sessionID))
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var out []checkpoint.Checkpoint
	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".json" {
			continue
		}
		data, err := os.ReadFile(filepath.Join(s.sessionDir(sessionID), entry.Name()))
		if err != nil {
			return nil, err
		}
		var cp checkpoint.Checkpoint
		if err := json.Unmarshal(data, &cp); err != nil {
			return nil, err
		}
		out = append(out, cp)
	}
	sort.Slice(out, func(i, j int) bool {
		return out[i].CreatedAt.After(out[j].CreatedAt)
	})
	return out, nil
}

func (s *fileStore) Delete(_ context.Context, checkpointID string) error {
	sessions, err := s.sessions()
	if err != nil {
		return err
	}
	for _, sessionID := range sessions {
		path := filepath.Join(s.sessionDir(sessionID), hex.EncodeToString([]byte(checkpointID))+".json")
		if err := os.Remove(path); err == nil {
			return nil
		}
	}
	return os.ErrNotExist
}

func (s *fileStore) sessions() ([]string, error) {
	entries, err := os.ReadDir(filepath.Join(s.root, "sessions"))
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var out []string
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		decoded, err := hex.DecodeString(entry.Name())
		if err == nil {
			out = append(out, string(decoded))
		}
	}
	return out, nil
}
