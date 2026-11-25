package main

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestDurableApprovalLeaseAndReplay(t *testing.T) {
	ctx := context.Background()
	store := newMemoryStore()
	ledger := newEffectLedger()
	leases := newDurableLeaseStore()
	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)

	outcome, err := runDurable(ctx, store, ledger, leases, "run-1", "worker-a", false, now)
	if !errors.Is(err, errApprovalPending) || outcome.Status != "awaiting_approval" {
		t.Fatalf("pending = %+v, %v", outcome, err)
	}
	if ledger.Count() != 0 {
		t.Fatal("effect ran before approval")
	}

	outcome, err = runDurable(ctx, store, ledger, leases, "run-1", "worker-a", true, now)
	if err != nil || !outcome.Applied || outcome.Output != "order-42-refunded" {
		t.Fatalf("approved = %+v, %v", outcome, err)
	}
	if ledger.Count() != 1 || outcome.Status != "completed" {
		t.Fatalf("ledger=%d outcome=%+v", ledger.Count(), outcome)
	}
	cp, err := store.LoadRun(ctx, "run-1")
	if err != nil {
		t.Fatal(err)
	}
	if cp == nil || cp.EffectCursor == nil || cp.EffectCursor.LastEffectID != "run-1" {
		t.Fatalf("checkpoint = %+v", cp)
	}

	outcome, err = runDurable(ctx, store, ledger, leases, "run-1", "worker-b", true, now.Add(time.Hour))
	if err != nil || outcome.Applied || outcome.Output != "order-42-refunded" {
		t.Fatalf("replay = %+v, %v", outcome, err)
	}
	if ledger.Count() != 1 {
		t.Fatalf("replay changed ledger to %d", ledger.Count())
	}
}

func TestLeaseFencingAndExpiry(t *testing.T) {
	leases := newDurableLeaseStore()
	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)

	tokenA, err := leases.Acquire("run-1", "worker-a", now, time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	if !leases.Valid("run-1", tokenA, now) {
		t.Fatal("worker-a lease is not valid")
	}
	if _, err := leases.Acquire("run-1", "worker-b", now, time.Minute); !errors.Is(err, errLeaseHeld) {
		t.Fatalf("worker-b err = %v, want errLeaseHeld", err)
	}
	if leases.Valid("run-1", tokenA, now.Add(2*time.Minute)) {
		t.Fatal("expired lease still valid")
	}
	tokenB, err := leases.Acquire("run-1", "worker-b", now.Add(2*time.Minute), time.Minute)
	if err != nil {
		t.Fatal(err)
	}
	if leases.Valid("run-1", tokenA, now.Add(2*time.Minute)) {
		t.Fatal("old lease accepted after failover")
	}
	if !leases.Valid("run-1", tokenB, now.Add(2*time.Minute)) {
		t.Fatal("new lease invalid")
	}
}
