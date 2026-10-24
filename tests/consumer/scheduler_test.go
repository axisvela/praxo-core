package consumer_test

import (
	"sync"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/scheduler"
)

func TestPublishedSchedulerDisableWaitsForDispatch(t *testing.T) {
	started := make(chan struct{}, 1)
	release := make(chan struct{})
	var mu sync.Mutex
	fired := 0
	engine := scheduler.NewEngine(func(*scheduler.Schedule) {
		mu.Lock()
		fired++
		mu.Unlock()
		select {
		case started <- struct{}{}:
		default:
		}
		<-release
	})
	engine.Start()
	defer engine.Stop()
	if err := engine.Add(&scheduler.Schedule{ID: "s1", CronExpr: "@every 10ms", Enabled: true}); err != nil {
		t.Fatal(err)
	}
	select {
	case <-started:
	case <-time.After(2 * time.Second):
		t.Fatal("schedule did not fire")
	}
	done := make(chan struct{})
	go func() {
		_ = engine.SetEnabled("s1", false)
		close(done)
	}()
	select {
	case <-done:
		t.Fatal("disable returned before dispatch completed")
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
