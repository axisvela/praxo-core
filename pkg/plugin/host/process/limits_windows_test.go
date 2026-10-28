package process

import (
	"sync"
	"testing"
)

func TestJobResourceHandleConcurrentCloseUsageAndTermination(t *testing.T) {
	for iteration := 0; iteration < 16; iteration++ {
		job, err := createJobObject()
		if err != nil {
			t.Fatal(err)
		}
		handle := &jobResourceHandle{job: job}
		start := make(chan struct{})
		var workers sync.WaitGroup
		for worker := 0; worker < 3; worker++ {
			workers.Add(1)
			go func(worker int) {
				defer workers.Done()
				<-start
				for call := 0; call < 32; call++ {
					switch worker {
					case 0:
						if err := handle.Close(); err != nil {
							t.Errorf("close: %v", err)
						}
					case 1:
						if _, err := handle.Usage(); err != nil {
							t.Errorf("usage: %v", err)
						}
					case 2:
						killProcessTree(handle, nil)
					}
				}
			}(worker)
		}
		close(start)
		workers.Wait()
		if err := handle.Close(); err != nil {
			t.Fatal(err)
		}
	}
}
