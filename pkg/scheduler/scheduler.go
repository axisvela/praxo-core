// Package scheduler defines durable schedule contracts.
package scheduler

import (
	"context"
	"time"
)

// Kind is a schedule kind.
type Kind string

const (
	KindCron     Kind = "cron"
	KindInterval Kind = "interval"
	KindOnce     Kind = "once"
	KindEvent    Kind = "event"
)

// Schedule is a durable schedule definition.
type Schedule struct {
	ID            string    `json:"id"`
	TenantID      string    `json:"tenantId"`
	WorkspaceID   string    `json:"workspaceId"`
	Kind          Kind      `json:"kind"`
	Expression    string    `json:"expression"`
	Timezone      string    `json:"timezone,omitempty"`
	MisfirePolicy string    `json:"misfirePolicy,omitempty"`
	Enabled       bool      `json:"enabled"`
	NextRun       time.Time `json:"nextRun,omitempty"`
}

// Scheduler manages durable schedules. Execution belongs to the runtime.
type Scheduler interface {
	Add(ctx context.Context, schedule Schedule) error
	Remove(ctx context.Context, id string) error
	List(ctx context.Context, tenantID string) ([]Schedule, error)
}
