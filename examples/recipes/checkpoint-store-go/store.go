package checkpoint_store_recipe

import (
	"context"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path"
	"sort"
	"strings"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
)

// FileStore is an application-owned checkpoint store backed by JSON files.
// It uses temp-file writes, fsync, and rename to avoid exposing a partially
// written checkpoint. It is a teaching implementation, not a concurrent or
// power-loss-proof database.
type FileStore struct {
	root *os.Root
}

var _ checkpoint.Store = (*FileStore)(nil)

// OpenFileStore creates or opens a checkpoint directory.
func OpenFileStore(directory string) (*FileStore, error) {
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return nil, err
	}
	root, err := os.OpenRoot(directory)
	if err != nil {
		return nil, err
	}
	return &FileStore{root: root}, nil
}

// Close releases the directory handle.
func (s *FileStore) Close() error {
	return s.root.Close()
}

func sessionDir(sessionID string) string {
	return path.Join("sessions", hex.EncodeToString([]byte(sessionID)))
}

func checkpointName(checkpointID string) string {
	return hex.EncodeToString([]byte(checkpointID)) + ".json"
}

// Save persists a checkpoint and replaces an earlier checkpoint for the same
// session and run.
func (s *FileStore) Save(_ context.Context, cp *checkpoint.Checkpoint) error {
	if cp == nil {
		return errors.New("checkpoint is nil")
	}
	if cp.ID == "" || cp.SessionID == "" || cp.RunID == "" {
		return errors.New("checkpoint needs an id, session id, and run id")
	}
	if cp.CreatedAt.IsZero() {
		cp.CreatedAt = time.Now().UTC()
	}
	directory := sessionDir(cp.SessionID)
	if err := s.root.MkdirAll(directory, 0o700); err != nil {
		return err
	}
	existing, err := s.list(cp.SessionID)
	if err != nil {
		return err
	}
	for _, item := range existing {
		if item.RunID == cp.RunID {
			_ = s.root.Remove(path.Join(directory, checkpointName(item.ID)))
		}
	}

	encoded, err := json.Marshal(cp)
	if err != nil {
		return err
	}
	final := path.Join(directory, checkpointName(cp.ID))
	temporary := final + ".tmp"
	file, err := s.root.OpenFile(temporary, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	if _, err := file.Write(encoded); err != nil {
		file.Close()
		return err
	}
	if err := file.Sync(); err != nil {
		file.Close()
		return err
	}
	if err := file.Close(); err != nil {
		return err
	}
	_ = s.root.Remove(final)
	return s.root.Rename(temporary, final)
}

func (s *FileStore) list(sessionID string) ([]checkpoint.Checkpoint, error) {
	directory := sessionDir(sessionID)
	file, err := s.root.Open(directory)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	entries, err := file.ReadDir(-1)
	file.Close()
	if err != nil {
		return nil, err
	}
	var out []checkpoint.Checkpoint
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".json") {
			continue
		}
		data, err := s.root.ReadFile(path.Join(directory, entry.Name()))
		if err != nil {
			return nil, err
		}
		var cp checkpoint.Checkpoint
		if err := json.Unmarshal(data, &cp); err != nil {
			return nil, fmt.Errorf("decode %s: %w", entry.Name(), err)
		}
		out = append(out, cp)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].CreatedAt.Equal(out[j].CreatedAt) {
			return out[i].ID > out[j].ID
		}
		return out[i].CreatedAt.After(out[j].CreatedAt)
	})
	return out, nil
}

func (s *FileStore) sessions() ([]string, error) {
	file, err := s.root.Open("sessions")
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	entries, err := file.ReadDir(-1)
	file.Close()
	if err != nil {
		return nil, err
	}
	var out []string
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		decoded, err := hex.DecodeString(entry.Name())
		if err != nil {
			continue
		}
		out = append(out, string(decoded))
	}
	return out, nil
}

// Load returns the newest checkpoint for a session.
func (s *FileStore) Load(_ context.Context, sessionID string) (*checkpoint.Checkpoint, error) {
	items, err := s.list(sessionID)
	if err != nil || len(items) == 0 {
		return nil, err
	}
	return &items[0], nil
}

// LoadScoped returns the newest checkpoint for a session, optionally filtered
// by tenant.
func (s *FileStore) LoadScoped(_ context.Context, tenantID, sessionID string) (*checkpoint.Checkpoint, error) {
	items, err := s.list(sessionID)
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

// LoadRun returns the newest checkpoint for a run.
func (s *FileStore) LoadRun(ctx context.Context, runID string) (*checkpoint.Checkpoint, error) {
	return s.LoadRunScoped(ctx, "", runID)
}

// LoadRunScoped returns the newest checkpoint for a run, optionally filtered by
// tenant.
func (s *FileStore) LoadRunScoped(_ context.Context, tenantID, runID string) (*checkpoint.Checkpoint, error) {
	sessionIDs, err := s.sessions()
	if err != nil {
		return nil, err
	}
	var best *checkpoint.Checkpoint
	for _, sessionID := range sessionIDs {
		items, err := s.list(sessionID)
		if err != nil {
			return nil, err
		}
		for i := range items {
			item := &items[i]
			if item.RunID != runID {
				continue
			}
			if tenantID != "" && item.TenantID != tenantID {
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

// List returns all checkpoints for a session, newest first.
func (s *FileStore) List(_ context.Context, sessionID string) ([]checkpoint.Checkpoint, error) {
	return s.list(sessionID)
}

// Delete removes a checkpoint by id.
func (s *FileStore) Delete(_ context.Context, checkpointID string) error {
	sessionIDs, err := s.sessions()
	if err != nil {
		return err
	}
	for _, sessionID := range sessionIDs {
		items, err := s.list(sessionID)
		if err != nil {
			return err
		}
		for _, item := range items {
			if item.ID == checkpointID {
				return s.root.Remove(path.Join(sessionDir(sessionID), checkpointName(item.ID)))
			}
		}
	}
	return nil
}
