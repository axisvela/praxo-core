package agent

// Status is the lifecycle state of an agent session or run.
type Status string

// Agent session and run states.
const (
	StatusIdle            Status = "idle"
	StatusPlanning        Status = "planning"
	StatusWaitingApproval Status = "waiting_approval"
	StatusExecuting       Status = "executing"
	StatusObserving       Status = "observing"
	StatusReplanning      Status = "replanning"
	StatusPaused          Status = "paused"
	StatusCancelled       Status = "cancelled"
	StatusCompleted       Status = "completed"
	StatusFailed          Status = "failed"
)

// DefaultTenantID is used when a host does not scope a session to a tenant.
const DefaultTenantID = "default"
