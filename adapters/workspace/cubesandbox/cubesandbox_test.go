package cubesandbox

import (
	"context"
	"fmt"
	"path"
	"strings"
	"sync"
	"testing"
	"time"

	cubesandboxsdk "github.com/tencentcloud/CubeSandbox/sdk/go"

	"github.com/axisvela/praxo-core/adapters/workspace/conformance"
)

func TestProviderConformance(t *testing.T) {
	client := newFakeClient()
	provider := newProvider(client, Config{})
	err := conformance.CheckProvider(context.Background(), provider, conformance.Case{
		Command:            []string{"echo", "ok"},
		WantStdoutContains: "echo ok",
		Path:               "nested/file.txt",
		Content:            []byte("conformance"),
	})
	if err != nil {
		t.Fatal(err)
	}
}

type fakeClient struct {
	mu        sync.Mutex
	sandboxes map[string]*fakeSandbox
	next      int
}

func newFakeClient() *fakeClient {
	return &fakeClient{sandboxes: map[string]*fakeSandbox{}}
}

func (c *fakeClient) Create(context.Context, cubesandboxsdk.CreateOptions) (sdkSandbox, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.next++
	sandbox := &fakeSandbox{
		id:     fmt.Sprintf("sbx-%d", c.next),
		client: c,
		files:  map[string][]byte{},
	}
	c.sandboxes[sandbox.id] = sandbox
	return sandbox, nil
}

func (c *fakeClient) Connect(_ context.Context, id string) (sdkSandbox, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	sandbox, ok := c.sandboxes[id]
	if !ok {
		return nil, &cubesandboxsdk.NotFoundError{Path: id, Message: "sandbox not found"}
	}
	return sandbox, nil
}

type fakeSandbox struct {
	mu     sync.Mutex
	id     string
	client *fakeClient
	files  map[string][]byte
}

func (s *fakeSandbox) ID() string { return s.id }

func (s *fakeSandbox) Run(context.Context, string, string, map[string]string, time.Duration) (*cubesandboxsdk.CommandResult, error) {
	return &cubesandboxsdk.CommandResult{Stdout: "echo ok", ExitCode: 0}, nil
}

func (s *fakeSandbox) Stat(_ context.Context, target string) (*cubesandboxsdk.FileEntry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	entry, ok := s.stat(target)
	if !ok {
		return nil, &cubesandboxsdk.NotFoundError{Path: target, Message: "not found"}
	}
	return entry, nil
}

func (s *fakeSandbox) List(_ context.Context, target string) ([]cubesandboxsdk.FileEntry, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.list(target)
}

func (s *fakeSandbox) Read(_ context.Context, target string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, ok := s.files[target]
	if !ok {
		return nil, &cubesandboxsdk.NotFoundError{Path: target, Message: "not found"}
	}
	return data, nil
}

func (s *fakeSandbox) Write(_ context.Context, target string, data []byte) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.files[target] = append([]byte(nil), data...)
	return nil
}

func (s *fakeSandbox) Remove(_ context.Context, target string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.files[target]; ok {
		delete(s.files, target)
		return nil
	}
	prefix := target + "/"
	found := false
	for name := range s.files {
		if strings.HasPrefix(name, prefix) {
			delete(s.files, name)
			found = true
		}
	}
	if !found {
		return &cubesandboxsdk.NotFoundError{Path: target, Message: "not found"}
	}
	return nil
}

func (s *fakeSandbox) Pause(context.Context) error  { return nil }
func (s *fakeSandbox) Resume(context.Context) error { return nil }

func (s *fakeSandbox) Kill(context.Context) error {
	s.client.mu.Lock()
	delete(s.client.sandboxes, s.id)
	s.client.mu.Unlock()
	return nil
}

func (s *fakeSandbox) stat(target string) (*cubesandboxsdk.FileEntry, bool) {
	if data, ok := s.files[target]; ok {
		return &cubesandboxsdk.FileEntry{
			Name: path.Base(target),
			Path: target,
			Type: "FILE_TYPE_FILE",
			Size: int64(len(data)),
		}, true
	}
	if s.hasDir(target) {
		return &cubesandboxsdk.FileEntry{
			Name: path.Base(target),
			Path: target,
			Type: "FILE_TYPE_DIRECTORY",
		}, true
	}
	return nil, false
}

func (s *fakeSandbox) list(target string) ([]cubesandboxsdk.FileEntry, error) {
	if _, ok := s.files[target]; ok {
		return nil, &cubesandboxsdk.NotFoundError{Path: target, Message: "not a directory"}
	}
	prefix := target
	if target == "." {
		prefix = ""
	} else {
		prefix = target + "/"
	}
	seen := map[string]bool{}
	var out []cubesandboxsdk.FileEntry
	for name, data := range s.files {
		if !strings.HasPrefix(name, prefix) {
			continue
		}
		rest := strings.TrimPrefix(name, prefix)
		part := strings.SplitN(rest, "/", 2)[0]
		if seen[part] {
			continue
		}
		seen[part] = true
		child := part
		if target != "." {
			child = path.Join(target, part)
		}
		if strings.Contains(rest, "/") {
			out = append(out, cubesandboxsdk.FileEntry{Name: part, Path: child, Type: "FILE_TYPE_DIRECTORY"})
			continue
		}
		out = append(out, cubesandboxsdk.FileEntry{Name: part, Path: child, Type: "FILE_TYPE_FILE", Size: int64(len(data))})
	}
	if len(out) == 0 {
		return nil, &cubesandboxsdk.NotFoundError{Path: target, Message: "not found"}
	}
	return out, nil
}

func (s *fakeSandbox) hasDir(target string) bool {
	if target == "." {
		return len(s.files) > 0
	}
	prefix := target + "/"
	for name := range s.files {
		if strings.HasPrefix(name, prefix) {
			return true
		}
	}
	return false
}
