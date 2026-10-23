// Package multiagent provides optional supervisor and sequential delegation over
// pkg/agent/delegation. It is not a graph or durable workflow runtime.
package multiagent

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent/delegation"
)

var (
	// ErrRunnerRequired is returned when no subagent runner is configured.
	ErrRunnerRequired = errors.New("multiagent: subagent runner is required")
	// ErrTimeout is returned when workers do not finish before the deadline.
	ErrTimeout = errors.New("multiagent: supervisor timeout")
)

// Worker describes one delegated subagent run.
type Worker struct {
	Name    string
	AgentID string
	Prompt  string
	Mode    delegation.SubagentMode
	Context map[string]any
}

// Supervisor runs delegated workers through delegation.SubagentManager.
type Supervisor struct {
	Runner       delegation.SubagentRunner
	Timeout      time.Duration
	PollInterval time.Duration
}

// Run launches all workers in parallel and waits for completion.
func (s Supervisor) Run(ctx context.Context, parentSessionID string, workers []Worker) (map[string]string, error) {
	names, err := validate(workers)
	if err != nil {
		return nil, err
	}
	if s.Runner == nil {
		return nil, ErrRunnerRequired
	}
	if len(workers) == 0 {
		return map[string]string{}, nil
	}
	manager := delegation.NewSubagentManager(s.Runner)
	tasks := make(map[string]string, len(workers))
	for _, worker := range workers {
		task, err := manager.Launch(ctx, request(parentSessionID, worker))
		if err != nil {
			cancelAll(manager, tasks)
			return nil, err
		}
		tasks[names[worker.AgentID]] = task.ID
	}
	return s.wait(ctx, manager, tasks)
}

// Sequential runs workers in order and passes each output to the next worker as
// Context["previous"]. It is a simple handoff chain, not a durable workflow.
func (s Supervisor) Sequential(ctx context.Context, parentSessionID string, workers []Worker) (map[string]string, error) {
	names, err := validate(workers)
	if err != nil {
		return nil, err
	}
	if s.Runner == nil {
		return nil, ErrRunnerRequired
	}
	manager := delegation.NewSubagentManager(s.Runner)
	outputs := make(map[string]string, len(workers))
	previous := ""
	for _, worker := range workers {
		worker = withPrevious(worker, previous)
		task, err := manager.Launch(ctx, request(parentSessionID, worker))
		if err != nil {
			return nil, err
		}
		name := names[worker.AgentID]
		result, err := s.wait(ctx, manager, map[string]string{name: task.ID})
		if err != nil {
			return nil, err
		}
		outputs[name] = result[name]
		previous = result[name]
	}
	return outputs, nil
}

func (s Supervisor) wait(ctx context.Context, manager *delegation.SubagentManager, tasks map[string]string) (map[string]string, error) {
	timeout := s.Timeout
	if timeout <= 0 {
		timeout = 2 * time.Minute
	}
	interval := s.PollInterval
	if interval <= 0 {
		interval = 10 * time.Millisecond
	}
	deadline := time.Now().Add(timeout)
	outputs := make(map[string]string, len(tasks))
	for {
		active := 0
		for name, taskID := range tasks {
			task, ok := manager.Check(taskID)
			if !ok {
				cancelAll(manager, tasks)
				return nil, fmt.Errorf("multiagent: missing task %s", taskID)
			}
			switch task.Status {
			case delegation.SubagentCompleted:
				if _, done := outputs[name]; !done {
					outputs[name] = task.Output
				}
			case delegation.SubagentFailed:
				cancelAll(manager, tasks)
				return nil, fmt.Errorf("multiagent: %s failed: %s", name, task.Error)
			case delegation.SubagentCanceled:
				cancelAll(manager, tasks)
				return nil, fmt.Errorf("multiagent: %s canceled", name)
			default:
				active++
			}
		}
		if active == 0 {
			return outputs, nil
		}
		select {
		case <-ctx.Done():
			cancelAll(manager, tasks)
			return nil, ctx.Err()
		case <-time.After(interval):
		}
		if time.Now().After(deadline) {
			cancelAll(manager, tasks)
			return nil, ErrTimeout
		}
	}
}

func request(parentSessionID string, worker Worker) delegation.SubagentRequest {
	return delegation.SubagentRequest{
		ParentSessionID: parentSessionID,
		AgentID:         worker.AgentID,
		Prompt:          worker.Prompt,
		Mode:            worker.Mode,
		Context:         worker.Context,
	}
}

func validate(workers []Worker) (map[string]string, error) {
	names := make(map[string]string, len(workers))
	seenNames := make(map[string]bool, len(workers))
	for _, worker := range workers {
		if worker.AgentID == "" {
			return nil, errors.New("multiagent: worker agent ID is required")
		}
		name := worker.Name
		if name == "" {
			name = worker.AgentID
		}
		if _, exists := names[worker.AgentID]; exists {
			return nil, fmt.Errorf("multiagent: duplicate worker %s", worker.AgentID)
		}
		if seenNames[name] {
			return nil, fmt.Errorf("multiagent: duplicate worker name %s", name)
		}
		names[worker.AgentID] = name
		seenNames[name] = true
	}
	return names, nil
}

func withPrevious(worker Worker, previous string) Worker {
	context := make(map[string]any, len(worker.Context)+1)
	for key, value := range worker.Context {
		context[key] = value
	}
	context["previous"] = previous
	worker.Context = context
	return worker
}

func cancelAll(manager *delegation.SubagentManager, tasks map[string]string) {
	for _, taskID := range tasks {
		_ = manager.Cancel(taskID)
	}
}
