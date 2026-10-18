package delegation

import (
	"context"
	"errors"
	"fmt"
	"sort"
	"sync"
	"sync/atomic"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/model"
)

// SubagentMode selects how a child run receives context.
type SubagentMode string

const (
	// SubagentIsolated starts the child with only the request prompt/context.
	SubagentIsolated SubagentMode = "isolated"
	// SubagentFork starts the child with the parent's full message history.
	SubagentFork SubagentMode = "fork"
)

// SubagentStatus is the lifecycle state of one delegated task.
type SubagentStatus string

// Subagent task statuses.
const (
	SubagentQueued    SubagentStatus = "queued"
	SubagentRunning   SubagentStatus = "running"
	SubagentCompleted SubagentStatus = "completed"
	SubagentFailed    SubagentStatus = "failed"
	SubagentCanceled  SubagentStatus = "canceled"
)

// SubagentRequest describes one delegated child run.
type SubagentRequest struct {
	ParentSessionID string
	AgentID         string
	Prompt          string
	Context         map[string]any
	Mode            SubagentMode
	History         []model.Message
}

// SubagentResult is the outcome of one child run.
type SubagentResult struct {
	TaskID  string
	AgentID string
	Output  string
	Usage   model.Usage
}

// SubagentRunner executes a delegated child run.
type SubagentRunner interface {
	Run(ctx context.Context, req SubagentRequest) (SubagentResult, error)
}

// ControllableRunner optionally supports mid-flight steering.
type ControllableRunner interface {
	SubagentRunner
	Update(ctx context.Context, taskID, prompt string) error
}

// SubagentTask is the observable state of one delegated task.
type SubagentTask struct {
	ID              string         `json:"id"`
	ParentSessionID string         `json:"parentSessionId"`
	AgentID         string         `json:"agentId"`
	Mode            SubagentMode   `json:"mode"`
	Status          SubagentStatus `json:"status"`
	Output          string         `json:"output,omitempty"`
	Error           string         `json:"error,omitempty"`
	CreatedAt       time.Time      `json:"createdAt"`
	UpdatedAt       time.Time      `json:"updatedAt"`
}

// ErrSubagentUpdateUnsupported reports that a runner cannot accept an update.
var ErrSubagentUpdateUnsupported = errors.New("agent: subagent update unsupported")

type subagentState struct {
	task   SubagentTask
	cancel context.CancelFunc
}

// SubagentManager owns asynchronous delegated tasks over a SubagentRunner.
type SubagentManager struct {
	runner SubagentRunner
	mu     sync.Mutex
	tasks  map[string]*subagentState
	seq    atomic.Uint64
}

// NewSubagentManager returns a manager over runner.
func NewSubagentManager(runner SubagentRunner) *SubagentManager {
	return &SubagentManager{runner: runner, tasks: make(map[string]*subagentState)}
}

// Launch starts a child run and returns its initial task state.
func (m *SubagentManager) Launch(ctx context.Context, req SubagentRequest) (SubagentTask, error) {
	if m.runner == nil {
		return SubagentTask{}, errors.New("agent: subagent runner is required")
	}
	if req.ParentSessionID == "" || req.AgentID == "" {
		return SubagentTask{}, errors.New("agent: subagent parent session and agent id are required")
	}
	if req.Mode == "" {
		req.Mode = SubagentIsolated
	}
	now := time.Now().UTC()
	id := fmt.Sprintf("subagent-%d", m.seq.Add(1))
	runCtx, cancel := context.WithCancel(ctx)
	task := SubagentTask{
		ID: id, ParentSessionID: req.ParentSessionID, AgentID: req.AgentID,
		Mode: req.Mode, Status: SubagentQueued, CreatedAt: now, UpdatedAt: now,
	}
	m.mu.Lock()
	m.tasks[id] = &subagentState{task: task, cancel: cancel}
	m.mu.Unlock()

	go func() {
		m.setStatus(id, SubagentRunning, "", "")
		res, err := m.runner.Run(runCtx, req)
		if runCtx.Err() != nil {
			m.setStatus(id, SubagentCanceled, "", "")
			return
		}
		if err != nil {
			m.setStatus(id, SubagentFailed, "", err.Error())
			return
		}
		m.setStatus(id, SubagentCompleted, res.Output, "")
	}()
	task, _ = m.Check(id)
	return task, nil
}

// Check returns the current state of a task.
func (m *SubagentManager) Check(taskID string) (SubagentTask, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	st, ok := m.tasks[taskID]
	if !ok {
		return SubagentTask{}, false
	}
	return st.task, true
}

// Update forwards a mid-flight steering prompt when the runner supports it.
func (m *SubagentManager) Update(ctx context.Context, taskID, prompt string) error {
	runner, ok := m.runner.(ControllableRunner)
	if !ok {
		return ErrSubagentUpdateUnsupported
	}
	if _, ok := m.Check(taskID); !ok {
		return fmt.Errorf("agent: unknown subagent task %q", taskID)
	}
	return runner.Update(ctx, taskID, prompt)
}

// Cancel stops a task and marks it canceled.
func (m *SubagentManager) Cancel(taskID string) error {
	m.mu.Lock()
	st, ok := m.tasks[taskID]
	if !ok {
		m.mu.Unlock()
		return fmt.Errorf("agent: unknown subagent task %q", taskID)
	}
	st.cancel()
	st.task.Status = SubagentCanceled
	st.task.UpdatedAt = time.Now().UTC()
	m.mu.Unlock()
	return nil
}

// List returns tasks for a parent session, oldest first. An empty parent
// session returns all tasks.
func (m *SubagentManager) List(parentSessionID string) []SubagentTask {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]SubagentTask, 0, len(m.tasks))
	for _, st := range m.tasks {
		if parentSessionID != "" && st.task.ParentSessionID != parentSessionID {
			continue
		}
		out = append(out, st.task)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].CreatedAt.Before(out[j].CreatedAt) })
	return out
}

func (m *SubagentManager) setStatus(taskID string, status SubagentStatus, output, errMsg string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	st, ok := m.tasks[taskID]
	if !ok {
		return
	}
	st.task.Status = status
	st.task.Output = output
	st.task.Error = errMsg
	st.task.UpdatedAt = time.Now().UTC()
}
