package flow

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

func TestChain(t *testing.T) {
	first := Func[int, int](func(_ context.Context, v int) (int, error) { return v + 1, nil })
	second := Func[int, string](func(_ context.Context, v int) (string, error) { return string(rune('0' + v)), nil })
	chain := Chain[int, int, string]{First: first, Second: second}
	got, err := chain.Invoke(context.Background(), 1)
	if err != nil || got != "2" {
		t.Fatalf("got %q, %v", got, err)
	}
}

func TestChainStopsOnError(t *testing.T) {
	sentinel := errors.New("stop")
	first := Func[int, int](func(context.Context, int) (int, error) { return 0, sentinel })
	second := Func[int, int](func(context.Context, int) (int, error) { t.Fatal("second should not run"); return 0, nil })
	_, err := (Chain[int, int, int]{First: first, Second: second}).Invoke(context.Background(), 1)
	if !errors.Is(err, sentinel) {
		t.Fatalf("err = %v", err)
	}
}

func TestParallel(t *testing.T) {
	p := Parallel[int, int]{Runnables: []Runnable[int, int]{
		Func[int, int](func(_ context.Context, v int) (int, error) { return v + 1, nil }),
		Func[int, int](func(_ context.Context, v int) (int, error) { return v + 2, nil }),
	}}
	got, err := p.Invoke(context.Background(), 1)
	if err != nil || len(got) != 2 || got[0] != 2 || got[1] != 3 {
		t.Fatalf("got %+v, %v", got, err)
	}
}

func TestParallelRunsConcurrently(t *testing.T) {
	const count = 3
	started := make(chan struct{}, count)
	release := make(chan struct{})
	var once sync.Once
	releaseAll := func() { once.Do(func() { close(release) }) }
	defer releaseAll()

	runnable := func(_ context.Context, v int) (int, error) {
		started <- struct{}{}
		<-release
		return v, nil
	}
	p := Parallel[int, int]{Runnables: []Runnable[int, int]{
		Func[int, int](runnable),
		Func[int, int](runnable),
		Func[int, int](runnable),
	}}
	done := make(chan struct{})
	var got []int
	var err error
	go func() {
		got, err = p.Invoke(context.Background(), 7)
		close(done)
	}()

	for i := 0; i < count; i++ {
		select {
		case <-started:
		case <-time.After(time.Second):
			t.Fatal("Parallel did not start all runnables concurrently")
		}
	}
	releaseAll()
	<-done
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != count {
		t.Fatalf("got %d outputs", len(got))
	}
	for _, value := range got {
		if value != 7 {
			t.Fatalf("value = %d", value)
		}
	}
}

func TestParallelReturnsFirstErrorInOrder(t *testing.T) {
	first := errors.New("first")
	second := errors.New("second")
	p := Parallel[int, int]{Runnables: []Runnable[int, int]{
		Func[int, int](func(context.Context, int) (int, error) { return 0, first }),
		Func[int, int](func(context.Context, int) (int, error) { return 0, second }),
	}}
	_, err := p.Invoke(context.Background(), 1)
	if !errors.Is(err, first) {
		t.Fatalf("err = %v, want %v", err, first)
	}
}
