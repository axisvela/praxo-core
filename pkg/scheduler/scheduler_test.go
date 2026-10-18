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
