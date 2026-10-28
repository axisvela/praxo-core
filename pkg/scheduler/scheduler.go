package scheduler

import (
	"errors"
	"fmt"
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
	mu         sync.RWMutex
	cron       *cron.Cron
	schedules  map[string]*Schedule
	entries    map[string]cron.EntryID
	dispatch   DispatchFunc
	dispatchWG sync.WaitGroup
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
	if s == nil {
		return errors.New("scheduler: schedule is required")
	}
	if s.ID == "" {
		return errors.New("scheduler: schedule id is required")
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	if s.CronExpr == "" {
		s.CronExpr = "@every 1h"
	}
	if _, err := cron.ParseStandard(s.CronExpr); err != nil {
		return fmt.Errorf("scheduler: invalid cron expression: %w", err)
	}
	if s.CreatedAt.IsZero() {
		s.CreatedAt = time.Now()
	}

	cp := *s
	var newEntry cron.EntryID
	if cp.Enabled {
		var err error
		newEntry, err = e.addCronEntry(&cp)
		if err != nil {
			return err
		}
	}

	oldEntry, hadOld := e.entries[cp.ID]
	e.schedules[cp.ID] = &cp
	if cp.Enabled {
		e.entries[cp.ID] = newEntry
	} else {
		delete(e.entries, cp.ID)
	}
	if hadOld {
		e.cron.Remove(oldEntry)
	}
	return nil
}

func (e *Engine) addCronEntry(s *Schedule) (cron.EntryID, error) {
	sid := s.ID
	entryID := new(cron.EntryID)
	var err error
	*entryID, err = e.cron.AddFunc(s.CronExpr, func() {
		e.mu.Lock()
		sch := e.schedules[sid]
		if sch == nil || !sch.Enabled {
			e.mu.Unlock()
			return
		}
		sch.LastRun = time.Now()
		if entry := e.cron.Entry(*entryID); !entry.Next.IsZero() {
			sch.NextRun = entry.Next
		}
		snapshot := *sch
		if e.dispatch != nil {
			e.dispatchWG.Add(1)
		}
		e.mu.Unlock()
		if e.dispatch != nil {
			defer e.dispatchWG.Done()
			e.dispatch(&snapshot)
		}
	})
	if err != nil {
		return 0, fmt.Errorf("scheduler: add entry: %w", err)
	}
	return *entryID, nil
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
	cp := *s
	return &cp, nil
}

// List returns all schedules.
func (e *Engine) List() []*Schedule {
	e.mu.RLock()
	defer e.mu.RUnlock()

	list := make([]*Schedule, 0, len(e.schedules))
	for _, s := range e.schedules {
		cp := *s
		list = append(list, &cp)
	}
	return list
}

// SetEnabled enables or disables a schedule.
func (e *Engine) SetEnabled(id string, enabled bool) error {
	e.mu.Lock()

	s, ok := e.schedules[id]
	if !ok || enabled == s.Enabled {
		e.mu.Unlock()
		return nil
	}

	s.Enabled = enabled

	if enabled {
		entryID, err := e.addCronEntry(s)
		if err != nil {
			s.Enabled = false
			e.mu.Unlock()
			return err
		}
		e.entries[id] = entryID
		e.mu.Unlock()
		return nil
	}
	if entryID, ok := e.entries[id]; ok {
		e.cron.Remove(entryID)
		delete(e.entries, id)
	}
	e.mu.Unlock()
	e.dispatchWG.Wait()
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
