package scheduler

import (
	"sync"
	"testing"
	"time"
)

func TestSchedulerAddAndFire(t *testing.T) {
	var mu sync.Mutex
	var fired []string

	eng := NewEngine(func(s *Schedule) {
		mu.Lock()
		fired = append(fired, s.ID)
		mu.Unlock()
	})
	eng.Start()
	defer eng.Stop()

	eng.Add(&Schedule{
		ID:       "sch-1",
		CronExpr: "@every 1s",
		Enabled:  true,
	})

	time.Sleep(1500 * time.Millisecond)

	mu.Lock()
	count := len(fired)
	mu.Unlock()

	if count < 1 {
		t.Fatal("expected at least 1 fire")
	}
}

func TestSchedulerAddAndList(t *testing.T) {
	eng := NewEngine(nil)
	eng.Start()
	defer eng.Stop()

	eng.Add(&Schedule{ID: "s1", CronExpr: "@every 10s", Enabled: true})
	eng.Add(&Schedule{ID: "s2", CronExpr: "@every 1h", Enabled: false})

	list := eng.List()
	if len(list) != 2 {
		t.Fatalf("expected 2 schedules, got %d", len(list))
	}
}

func TestSchedulerGet(t *testing.T) {
	eng := NewEngine(nil)
	eng.Start()
	defer eng.Stop()

	eng.Add(&Schedule{ID: "s1", Message: "run tests"})

	s, _ := eng.Get("s1")
	if s == nil {
		t.Fatal("expected schedule to exist")
	}
	if s.Message != "run tests" {
		t.Fatalf("expected 'run tests', got %q", s.Message)
	}
}

func TestSchedulerRemove(t *testing.T) {
	eng := NewEngine(nil)
	eng.Start()
	defer eng.Stop()

	eng.Add(&Schedule{ID: "s1", CronExpr: "@every 1h"})
	eng.Remove("s1")

	s, _ := eng.Get("s1")
	if s != nil {
		t.Fatal("expected nil after remove")
	}
}

func TestSchedulerEnableDisable(t *testing.T) {
	var mu sync.Mutex
	var fired []string

	eng := NewEngine(func(s *Schedule) {
		mu.Lock()
		fired = append(fired, s.ID)
		mu.Unlock()
	})
	eng.Start()
	defer eng.Stop()

	eng.Add(&Schedule{ID: "s1", CronExpr: "@every 100ms", Enabled: true})

	time.Sleep(300 * time.Millisecond)
	eng.SetEnabled("s1", false)

	mu.Lock()
	countWhenEnabled := len(fired)
	mu.Unlock()

	time.Sleep(300 * time.Millisecond)

	mu.Lock()
	countAfterDisabled := len(fired)
	mu.Unlock()

	if countAfterDisabled > countWhenEnabled {
		t.Fatal("expected no more fires after disable")
	}
}

func TestSchedulerDisableWaitsForInflightDispatch(t *testing.T) {
	started := make(chan struct{}, 1)
	release := make(chan struct{})
	var mu sync.Mutex
	fired := 0

	eng := NewEngine(func(*Schedule) {
		mu.Lock()
		fired++
		mu.Unlock()
		select {
		case started <- struct{}{}:
		default:
		}
		<-release
	})
	eng.Start()
	defer eng.Stop()
	eng.Add(&Schedule{ID: "s1", CronExpr: "@every 10ms", Enabled: true})

	select {
	case <-started:
	case <-time.After(2 * time.Second):
		t.Fatal("schedule did not fire")
	}
	done := make(chan struct{})
	go func() {
		_ = eng.SetEnabled("s1", false)
		close(done)
	}()
	select {
	case <-done:
		t.Fatal("disable returned before inflight dispatch completed")
	case <-time.After(20 * time.Millisecond):
	}
	close(release)
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("disable did not return")
	}

	mu.Lock()
	before := fired
	mu.Unlock()
	time.Sleep(50 * time.Millisecond)
	mu.Lock()
	after := fired
	mu.Unlock()
	if after != before {
		t.Fatalf("dispatch continued after disable: %d -> %d", before, after)
	}
}

func TestSchedulerDefaultCronExpr(t *testing.T) {
	eng := NewEngine(nil)
	eng.Start()
	defer eng.Stop()

	eng.Add(&Schedule{ID: "s1", Enabled: true})

	s, _ := eng.Get("s1")
	if s.CronExpr != "@every 1h" {
		t.Fatalf("expected default '@every 1h', got %q", s.CronExpr)
	}
}

func TestSchedulerCreatedAt(t *testing.T) {
	eng := NewEngine(nil)
	eng.Start()
	defer eng.Stop()

	eng.Add(&Schedule{ID: "s1"})

	s, _ := eng.Get("s1")
	if s.CreatedAt.IsZero() {
		t.Fatal("expected non-zero created_at")
	}
}

func TestSchedulerRejectsInvalidCron(t *testing.T) {
	eng := NewEngine(nil)
	err := eng.Add(&Schedule{ID: "bad", CronExpr: "not a cron", Enabled: true})
	if err == nil {
		t.Fatal("expected invalid cron error")
	}
	s, _ := eng.Get("bad")
	if s != nil {
		t.Fatal("invalid schedule was stored")
	}
	if entries := eng.cron.Entries(); len(entries) != 0 {
		t.Fatalf("invalid schedule registered %d entries", len(entries))
	}
}

func TestSchedulerDuplicateIDReplacesEntry(t *testing.T) {
	eng := NewEngine(nil)
	if err := eng.Add(&Schedule{ID: "same", CronExpr: "@every 1h", Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if entries := eng.cron.Entries(); len(entries) != 1 {
		t.Fatalf("entries = %d, want 1", len(entries))
	}
	if err := eng.Add(&Schedule{ID: "same", CronExpr: "@every 2h", Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if entries := eng.cron.Entries(); len(entries) != 1 {
		t.Fatalf("duplicate add left %d entries", len(entries))
	}
	s, _ := eng.Get("same")
	if s == nil || s.CronExpr != "@every 2h" {
		t.Fatalf("schedule = %+v", s)
	}
}

func TestSchedulerDisabledDuplicateRemovesEntry(t *testing.T) {
	eng := NewEngine(nil)
	if err := eng.Add(&Schedule{ID: "same", CronExpr: "@every 1h", Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if err := eng.Add(&Schedule{ID: "same", CronExpr: "@every 1h", Enabled: false}); err != nil {
		t.Fatal(err)
	}
	if entries := eng.cron.Entries(); len(entries) != 0 {
		t.Fatalf("disabled duplicate left %d entries", len(entries))
	}
	s, _ := eng.Get("same")
	if s == nil || s.Enabled {
		t.Fatalf("schedule = %+v", s)
	}
}

func TestSchedulerRejectsNilAndEmptyID(t *testing.T) {
	eng := NewEngine(nil)
	if err := eng.Add(nil); err == nil {
		t.Fatal("nil schedule accepted")
	}
	if err := eng.Add(&Schedule{CronExpr: "@every 1h"}); err == nil {
		t.Fatal("empty id accepted")
	}
	if len(eng.List()) != 0 {
		t.Fatalf("invalid adds stored schedules: %+v", eng.List())
	}
}
