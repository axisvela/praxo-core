package main

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/checkpoint"
)

var (
	errApprovalPending = errors.New("durable: approval pending")
	errLeaseHeld       = errors.New("durable: lease held by another worker")
)

type durableLease struct {
	owner     string
	token     string
	expiresAt time.Time
}

type durableLeaseStore struct {
	mu     sync.Mutex
	leases map[string]durableLease
}

func newDurableLeaseStore() *durableLeaseStore {
	return &durableLeaseStore{leases: map[string]durableLease{}}
}

func (s *durableLeaseStore) Acquire(runID, owner string, now time.Time, ttl time.Duration) (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if lease, ok := s.leases[runID]; ok && now.Before(lease.expiresAt) && lease.owner != owner {
		return "", errLeaseHeld
	}
	token := fmt.Sprintf("%s/%d", owner, now.UnixNano())
	s.leases[runID] = durableLease{owner: owner, token: token, expiresAt: now.Add(ttl)}
	return token, nil
}

func (s *durableLeaseStore) Valid(runID, token string, now time.Time) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	lease, ok := s.leases[runID]
	return ok && lease.token == token && now.Before(lease.expiresAt)
}

type durableOutcome struct {
	Output  string
	Applied bool
	Status  string
}

func runDurable(
	ctx context.Context,
	store *memoryStore,
	ledger *effectLedger,
	leases *durableLeaseStore,
	runID, owner string,
	approved bool,
	now time.Time,
) (durableOutcome, error) {
	cp, err := store.LoadRun(ctx, runID)
	if err != nil {
		return durableOutcome{}, err
	}
	if cp != nil && cp.Status == "completed" {
		value, applied, err := ledger.Apply(runID, func() (string, error) {
			return "order-42-refunded", nil
		})
		if err != nil {
			return durableOutcome{}, err
		}
		return durableOutcome{Output: value, Applied: applied, Status: cp.Status}, nil
	}
	if cp == nil {
		if err := store.Save(ctx, &checkpoint.Checkpoint{
			ID: runID + "-approval", SessionID: runID, RunID: runID,
			Status: "awaiting_approval", CreatedAt: now.UTC(),
		}); err != nil {
			return durableOutcome{}, err
		}
		return durableOutcome{Status: "awaiting_approval"}, errApprovalPending

	}
	if !approved {
		return durableOutcome{Status: cp.Status}, errApprovalPending
	}
	token, err := leases.Acquire(runID, owner, now, time.Minute)
	if err != nil {
		return durableOutcome{}, err
	}
	if !leases.Valid(runID, token, now) {
		return durableOutcome{}, errLeaseHeld
	}
	value, applied, err := ledger.Apply(runID, func() (string, error) {
		return "order-42-refunded", nil
	})
	if err != nil {
		return durableOutcome{}, err
	}
	if !leases.Valid(runID, token, now) {
		return durableOutcome{}, errLeaseHeld
	}
	cp.Status = "completed"
	cp.ID = runID + "-completed"
	cp.EffectCursor = &checkpoint.EffectCursor{
		RunID: runID, LastEffectID: runID, LastCreatedAt: now.UnixNano(),
	}
	cp.CreatedAt = now.UTC()
	if err := store.Save(ctx, cp); err != nil {
		return durableOutcome{}, err
	}
	return durableOutcome{Output: value, Applied: applied, Status: cp.Status}, nil
}
