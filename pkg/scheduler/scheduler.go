package scheduler

import (
	"sync"
	"time"

	"github.com/robfig/cron/v3"
)

// Schedule represents a scheduled agent run.
type Schedule struct {
	ID          string    `json:"id"`
	CronExpr    string    `json:"cron_expr"`
	WorkspaceID string    `json:"workspace_id"`
	Message     string    `json:"message"`
	ModelID     string    `json:"model_id"`
	Enabled     bool      `json:"enabled"`
	NextRun     time.Time `json:"next_run"`
	LastRun     time.Time `json:"last_run"`
	CreatedAt   time.Time `json:"created_at"`
}

// DispatchFunc is called when a schedule triggers.
type DispatchFunc func(schedule *Schedule)

// Engine manages cron-based schedule dispatch.
type Engine struct {
	mu        sync.RWMutex
	cron      *cron.Cron
	schedules map[string]*Schedule
	entries   map[string]cron.EntryID
	dispatch  DispatchFunc
}

// NewEngine creates a scheduler engine. dispatch is called when a schedule fires.
func NewEngine(dispatch DispatchFunc) *Engine {
	return &Engine{
		cron:      cron.New(cron.WithLocation(time.Local)),
		schedules: make(map[string]*Schedule),
		entries:   make(map[string]cron.EntryID),
		dispatch:  dispatch,
	}
}

// Add registers a new schedule. The engine must be started first.
func (e *Engine) Add(s *Schedule) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if s.CronExpr == "" {
		s.CronExpr = "@every 1h"
	}
	if s.CreatedAt.IsZero() {
		s.CreatedAt = time.Now()
	}

	e.schedules[s.ID] = s

	if s.Enabled {
		e.addCronEntry(s)
	}
	return nil
}

func (e *Engine) addCronEntry(s *Schedule) {
	sid := s.ID
	entryID := new(cron.EntryID)
	*entryID, _ = e.cron.AddFunc(s.CronExpr, func() {
		e.mu.RLock()
		sch := e.schedules[sid]
		e.mu.RUnlock()
		if sch == nil {
			return
		}
		sch.LastRun = time.Now()
		entry := e.cron.Entry(*entryID)
		if !entry.Next.IsZero() {
			sch.NextRun = entry.Next
		}
		if e.dispatch != nil {
			e.dispatch(sch)
		}
	})
	e.entries[s.ID] = *entryID
}

// Remove deletes a schedule.
func (e *Engine) Remove(id string) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	if entryID, ok := e.entries[id]; ok {
		e.cron.Remove(entryID)
		delete(e.entries, id)
	}
	delete(e.schedules, id)
	return nil
}

// Get returns a schedule by ID.
func (e *Engine) Get(id string) (*Schedule, error) {
	e.mu.RLock()
	defer e.mu.RUnlock()
	s, ok := e.schedules[id]
	if !ok {
		return nil, nil
	}
	return s, nil
}

// List returns all schedules.
func (e *Engine) List() []*Schedule {
	e.mu.RLock()
	defer e.mu.RUnlock()

	list := make([]*Schedule, 0, len(e.schedules))
	for _, s := range e.schedules {
		list = append(list, s)
	}
	return list
}

// SetEnabled enables or disables a schedule.
func (e *Engine) SetEnabled(id string, enabled bool) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	s, ok := e.schedules[id]
	if !ok {
		return nil
	}

	if enabled == s.Enabled {
		return nil
	}

	s.Enabled = enabled

	if enabled {
		e.addCronEntry(s)
	} else {
		if entryID, ok := e.entries[id]; ok {
			e.cron.Remove(entryID)
			delete(e.entries, id)
		}
	}
	return nil
}

// Start begins the scheduler loop. Must be called before Add.
func (e *Engine) Start() {
	e.cron.Start()
}

// Stop halts the scheduler loop. No more schedules will fire.
func (e *Engine) Stop() {
	ctx := e.cron.Stop()
	<-ctx.Done()
}
