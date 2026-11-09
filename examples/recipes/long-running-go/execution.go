package longrunning

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"sync"
)

var (
	errExecutionConflict = errors.New("execution identity conflicts with persisted request")
	errExecutionRecovery = errors.New("execution journal requires recovery")
	errExecutionUnknown  = errors.New("execution outcome is unknown; do not replay")
)

const (
	executionAdmitted    = "admitted"
	executionStartIntent = "start_intent"
	executionCompleted   = "completed"
	executionUnknown     = "unknown"
)

type executionRecord struct {
	Key    string `json:"key"`
	Digest string `json:"digest"`
	State  string `json:"state"`
}

type executionSnapshot struct {
	Version int                        `json:"version"`
	Records map[string]executionRecord `json:"records"`
}

type executionJournal struct {
	mu         sync.Mutex
	path       string
	data       executionSnapshot
	poisoned   bool
	commitHook func(string) error
}

func openExecutionJournal(path string) (*executionJournal, error) {
	if path == "" {
		return nil, errors.New("execution journal path is required")
	}
	journal := &executionJournal{path: path, data: executionSnapshot{Version: 1, Records: map[string]executionRecord{}}}
	encoded, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return journal, nil
	}
	if err != nil {
		return nil, err
	}
	decoder := json.NewDecoder(bytes.NewReader(encoded))
	decoder.DisallowUnknownFields()
	var snapshot executionSnapshot
	if err := decoder.Decode(&snapshot); err != nil {
		return nil, err
	}
	if err := decoder.Decode(new(any)); err != io.EOF {
		return nil, errors.New("trailing execution journal data")
	}
	journal.data = snapshot
	if journal.data.Version != 1 || journal.data.Records == nil {
		return nil, errors.New("invalid execution journal version or records")
	}
	recovered := false
	for key, record := range journal.data.Records {
		if key == "" || record.Key != key || record.Digest == "" {
			return nil, errors.New("invalid execution identity")
		}
		switch record.State {
		case executionStartIntent:
			record.State = executionUnknown
			journal.data.Records[key] = record
			recovered = true
		case executionAdmitted, executionCompleted, executionUnknown:
		default:
			return nil, errors.New("invalid execution state")
		}
	}
	if recovered {
		if err := journal.persist(journal.data, "recovery"); err != nil {
			return nil, err
		}
	}
	return journal, nil
}

func (j *executionJournal) Run(ctx context.Context, key, digest string, execute func(context.Context) error) (executionRecord, error) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if j.poisoned {
		return executionRecord{}, errExecutionRecovery
	}
	if ctx == nil || key == "" || digest == "" || execute == nil {
		return executionRecord{}, errors.New("execution requires context, identity, digest and executor")
	}
	if record, exists := j.data.Records[key]; exists {
		if record.Digest != digest {
			return executionRecord{}, errExecutionConflict
		}
		if record.State == executionUnknown || record.State == executionStartIntent {
			return record, errExecutionUnknown
		}
		return record, nil
	}
	if err := ctx.Err(); err != nil {
		return executionRecord{}, err
	}
	record := executionRecord{Key: key, Digest: digest, State: executionAdmitted}
	if err := j.commit(record, "admission"); err != nil {
		return executionRecord{}, err
	}
	if err := ctx.Err(); err != nil {
		return record, err
	}
	record.State = executionStartIntent
	if err := j.commit(record, "start"); err != nil {
		return executionRecord{}, err
	}
	j.poisoned = true
	executionErr := ctx.Err()
	if executionErr == nil {
		executionErr = execute(ctx)
	}
	j.poisoned = false
	record.State = executionCompleted
	if executionErr != nil || ctx.Err() != nil {
		record.State = executionUnknown
		executionErr = errors.Join(errExecutionUnknown, executionErr, ctx.Err())
	}
	if err := j.commit(record, "finish"); err != nil {
		return executionRecord{}, errors.Join(err, executionErr)
	}
	return record, executionErr
}

func (j *executionJournal) commit(record executionRecord, stage string) error {
	next := executionSnapshot{Version: 1, Records: make(map[string]executionRecord, len(j.data.Records)+1)}
	for key, existing := range j.data.Records {
		next.Records[key] = existing
	}
	next.Records[record.Key] = record
	if err := j.persist(next, stage); err != nil {
		j.poisoned = true
		return errors.Join(errExecutionRecovery, err)
	}
	j.data = next
	return nil
}

func (j *executionJournal) persist(snapshot executionSnapshot, stage string) error {
	encoded, err := json.Marshal(snapshot)
	if err != nil {
		return err
	}
	file, err := os.CreateTemp(filepath.Dir(j.path), ".execution-*")
	if err != nil {
		return err
	}
	defer os.Remove(file.Name())
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
	if j.commitHook != nil {
		if err := j.commitHook(stage + ".before-rename"); err != nil {
			return err
		}
	}
	if err := os.Rename(file.Name(), j.path); err != nil {
		return err
	}
	if j.commitHook != nil {
		return j.commitHook(stage + ".after-rename")
	}
	return nil
}
