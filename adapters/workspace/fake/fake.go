// Package fake provides an in-memory workspace provider for contract and
// adapter tests. It is not an isolation boundary.
package fake

import (
	"context"
	"fmt"
	"path"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

var (
	_ contract.Provider = (*Provider)(nil)
	_ contract.Session  = (*Session)(nil)
	_ contract.Pauser   = (*Session)(nil)
)

type file struct {
	data    []byte
	modTime time.Time
}

// Provider creates in-memory sessions.
type Provider struct {
	mu       sync.Mutex
	sessions map[string]*Session
	seq      atomic.Uint64
}

// NewProvider returns an empty in-memory provider.
func NewProvider() *Provider {
	return &Provider{sessions: map[string]*Session{}}
}

// Create implements contract.Provider.
func (p *Provider) Create(_ context.Context, spec contract.Spec) (contract.Session, error) {
	id := fmt.Sprintf("fake-%d", p.seq.Add(1))
	session := &Session{
		id:       id,
		provider: p,
		spec:     spec,
		files:    map[string]file{},
	}
	p.mu.Lock()
	p.sessions[id] = session
	p.mu.Unlock()
	return session, nil
}

// Attach implements contract.Provider.
func (p *Provider) Attach(_ context.Context, id string) (contract.Session, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	session, ok := p.sessions[id]
	if !ok {
		return nil, contract.ErrNotFound
	}
	return session, nil
}

// Session is an in-memory workspace session.
type Session struct {
	mu       sync.Mutex
	id       string
	provider *Provider
	spec     contract.Spec
	files    map[string]file
	closed   bool
	paused   bool
}

// ID implements contract.Session.
func (s *Session) ID() string { return s.id }

// Run implements sandbox.Sandbox without executing host commands.
func (s *Session) Run(_ context.Context, _ sandbox.Spec, command []string) (sandbox.Result, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return sandbox.Result{}, contract.ErrClosed
	}
	if len(command) == 0 {
		return sandbox.Result{}, fmt.Errorf("workspace/fake: command is required")
	}
	return sandbox.Result{Stdout: strings.Join(command, " ")}, nil
}

// Stat implements vfs.Backend.
func (s *Session) Stat(_ context.Context, target string) (vfs.Entry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return vfs.Entry{}, contract.ErrClosed
	}
	key, err := cleanPath(target)
	if err != nil {
		return vfs.Entry{}, err
	}
	if item, ok := s.files[key]; ok {
		return entry(key, item, false), nil
	}
	if s.hasDir(key) {
		return entry(key, file{}, true), nil
	}
	return vfs.Entry{}, vfs.ErrNotFound
}

// Read implements vfs.Backend.
func (s *Session) Read(_ context.Context, target string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return nil, contract.ErrClosed
	}
	key, err := cleanPath(target)
	if err != nil {
		return nil, err
	}
	item, ok := s.files[key]
	if !ok {
		return nil, vfs.ErrNotFound
	}
	return append([]byte(nil), item.data...), nil
}

// Write implements vfs.Backend.
func (s *Session) Write(_ context.Context, target string, data []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return contract.ErrClosed
	}
	key, err := cleanPath(target)
	if err != nil {
		return err
	}
	s.files[key] = file{data: append([]byte(nil), data...), modTime: time.Now().UTC()}
	return nil
}

// List implements vfs.Backend.
func (s *Session) List(_ context.Context, target string) ([]vfs.Entry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return nil, contract.ErrClosed
	}
	key, err := cleanPath(target)
	if err != nil {
		return nil, err
	}
	if _, ok := s.files[key]; ok {
		return nil, vfs.ErrNotFound
	}
	if !s.hasDir(key) {
		return nil, vfs.ErrNotFound
	}
	prefix := key + "/"
	seen := map[string]vfs.Entry{}
	for name, item := range s.files {
		if !strings.HasPrefix(name, prefix) {
			continue
		}
		rest := strings.TrimPrefix(name, prefix)
		part := strings.SplitN(rest, "/", 2)[0]
		child := path.Join(key, part)
		if len(strings.SplitN(rest, "/", 2)) == 1 {
			seen[part] = entry(child, item, false)
		} else {
			seen[part] = entry(child, file{}, true)
		}
	}
	out := make([]vfs.Entry, 0, len(seen))
	for _, item := range seen {
		out = append(out, item)
	}
	return out, nil
}

// Delete implements vfs.Backend.
func (s *Session) Delete(_ context.Context, target string, recursive bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return contract.ErrClosed
	}
	key, err := cleanPath(target)
	if err != nil {
		return err
	}
	if recursive {
		prefix := key + "/"
		for name := range s.files {
			if name == key || strings.HasPrefix(name, prefix) {
				delete(s.files, name)
			}
		}
		return nil
	}
	if _, ok := s.files[key]; ok {
		delete(s.files, key)
		return nil
	}
	if s.hasDir(key) {
		return fmt.Errorf("workspace/fake: directory is not empty")
	}
	return vfs.ErrNotFound
}

// Glob implements vfs.Backend.
func (s *Session) Glob(_ context.Context, pattern string) ([]string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return nil, contract.ErrClosed
	}
	var out []string
	for name := range s.files {
		ok, err := path.Match(pattern, name)
		if err != nil {
			return nil, err
		}
		if ok {
			out = append(out, name)
		}
	}
	return out, nil
}

// Grep implements vfs.Backend.
func (s *Session) Grep(_ context.Context, pattern, target string) ([]vfs.Match, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return nil, contract.ErrClosed
	}
	key, err := cleanPath(target)
	if err != nil {
		return nil, err
	}
	re, err := regexp.Compile(pattern)
	if err != nil {
		return nil, err
	}
	prefix := key + "/"
	var out []vfs.Match
	for name, item := range s.files {
		if name != key && !strings.HasPrefix(name, prefix) {
			continue
		}
		for index, line := range strings.Split(string(item.data), "\n") {
			if re.MatchString(line) {
				out = append(out, vfs.Match{Path: name, Line: index + 1, Text: line})
			}
		}
	}
	return out, nil
}

// Upload implements contract.Session.
func (s *Session) Upload(ctx context.Context, target string, data []byte) error {
	return s.Write(ctx, target, data)
}

// Download implements contract.Session.
func (s *Session) Download(ctx context.Context, target string) ([]byte, error) {
	return s.Read(ctx, target)
}

// Close implements contract.Session.
func (s *Session) Close(_ context.Context) error {
	s.mu.Lock()
	if s.closed {
		s.mu.Unlock()
		return nil
	}
	s.closed = true
	s.files = nil
	s.mu.Unlock()

	s.provider.mu.Lock()
	delete(s.provider.sessions, s.id)
	s.provider.mu.Unlock()
	return nil
}

// Pause implements contract.Pauser.
func (s *Session) Pause(_ context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return contract.ErrClosed
	}
	s.paused = true
	return nil
}

// Resume implements contract.Pauser.
func (s *Session) Resume(_ context.Context) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return contract.ErrClosed
	}
	s.paused = false
	return nil
}

func (s *Session) hasDir(key string) bool {
	prefix := key + "/"
	for name := range s.files {
		if strings.HasPrefix(name, prefix) {
			return true
		}
	}
	return false
}

func cleanPath(target string) (string, error) {
	clean := path.Clean(strings.TrimPrefix(target, "/"))
	if clean == "." || clean == ".." || strings.HasPrefix(clean, "../") {
		return "", fmt.Errorf("workspace/fake: invalid path %q", target)
	}
	return clean, nil
}

func entry(target string, item file, isDir bool) vfs.Entry {
	return vfs.Entry{
		Path:    target,
		Name:    path.Base(target),
		Size:    int64(len(item.data)),
		IsDir:   isDir,
		ModTime: item.modTime,
	}
}
