package main

import (
	"errors"
	"sync"
	"time"
)

var errEffectKeyRequired = errors.New("effect key is required")

type effectRecord struct {
	value     string
	createdAt time.Time
}

// effectLedger is an application-owned idempotency ledger. The checkpoint
// EffectCursor is only a recovery hint; the ledger is what prevents a repeated
// side effect after a restart.
type effectLedger struct {
	mu      sync.Mutex
	records map[string]effectRecord
	now     func() time.Time
}

func newEffectLedger() *effectLedger {
	return &effectLedger{records: map[string]effectRecord{}, now: time.Now}
}

func (l *effectLedger) Apply(key string, apply func() (string, error)) (string, bool, error) {
	if key == "" {
		return "", false, errEffectKeyRequired
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	if record, ok := l.records[key]; ok {
		return record.value, false, nil
	}
	value, err := apply()
	if err != nil {
		return "", false, err
	}
	l.records[key] = effectRecord{value: value, createdAt: l.now().UTC()}
	return value, true, nil
}

func (l *effectLedger) Count() int {
	l.mu.Lock()
	defer l.mu.Unlock()
	return len(l.records)
}
