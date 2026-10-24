package opensandbox

import (
	"context"
	"fmt"
	"io"
	"path"
	"strings"
	"sync"
	"testing"

	opensandboxsdk "github.com/alibaba/OpenSandbox/sdks/sandbox/go"

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

func (c *fakeClient) Create(context.Context, opensandboxsdk.SandboxCreateOptions) (sdkSandbox, error) {
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
		return nil, &opensandboxsdk.APIError{StatusCode: 404}
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

func (s *fakeSandbox) RunCommand(context.Context, opensandboxsdk.RunCommandRequest) (*opensandboxsdk.Execution, error) {
	exit := 0
	return &opensandboxsdk.Execution{
		Stdout:   []opensandboxsdk.OutputMessage{{Text: "echo ok"}},
		ExitCode: &exit,
	}, nil
}

func (s *fakeSandbox) GetFileInfo(_ context.Context, target string) (*opensandboxsdk.FileInfo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	info, ok := s.stat(target)
	if !ok {
		return nil, &opensandboxsdk.APIError{StatusCode: 404}
	}
	return info, nil
}

func (s *fakeSandbox) ListDirectory(_ context.Context, target string) ([]opensandboxsdk.FileInfo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.list(target)
}

func (s *fakeSandbox) UploadFile(_ context.Context, source io.Reader, remotePath string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, err := io.ReadAll(source)
	if err != nil {
		return err
	}
	s.files[remotePath] = data
	return nil
}

func (s *fakeSandbox) DownloadFile(_ context.Context, remotePath string) ([]byte, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	data, ok := s.files[remotePath]
	if !ok {
		return nil, &opensandboxsdk.APIError{StatusCode: 404}
	}
	return data, nil
}

func (s *fakeSandbox) Delete(_ context.Context, target string, recursive bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.files[target]; ok {
		delete(s.files, target)
		return nil
	}
	if recursive {
		prefix := target + "/"
		found := false
		for name := range s.files {
			if strings.HasPrefix(name, prefix) {
				delete(s.files, name)
				found = true
			}
		}
		if found {
			return nil
		}
	}
	return &opensandboxsdk.APIError{StatusCode: 404}
}

func (s *fakeSandbox) Pause(context.Context) error  { return nil }
func (s *fakeSandbox) Resume(context.Context) error { return nil }

func (s *fakeSandbox) Kill(context.Context) error {
	s.client.mu.Lock()
	delete(s.client.sandboxes, s.id)
	s.client.mu.Unlock()
	return nil
}

func (s *fakeSandbox) stat(target string) (*opensandboxsdk.FileInfo, bool) {
	if data, ok := s.files[target]; ok {
		return &opensandboxsdk.FileInfo{
			Path: target,
			Type: "file",
			Size: int64(len(data)),
		}, true
	}
	if s.hasDir(target) {
		return &opensandboxsdk.FileInfo{Path: target, Type: "directory"}, true
	}
	return nil, false
}

func (s *fakeSandbox) list(target string) ([]opensandboxsdk.FileInfo, error) {
	if _, ok := s.files[target]; ok {
		return nil, &opensandboxsdk.APIError{StatusCode: 404}
	}
	prefix := target
	if target == "." {
		prefix = ""
	} else {
		prefix = target + "/"
	}
	seen := map[string]bool{}
	var out []opensandboxsdk.FileInfo
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
			out = append(out, opensandboxsdk.FileInfo{Path: child, Type: "directory"})
			continue
		}
		out = append(out, opensandboxsdk.FileInfo{Path: child, Type: "file", Size: int64(len(data))})
	}
	if len(out) == 0 {
		return nil, &opensandboxsdk.APIError{StatusCode: 404}
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
