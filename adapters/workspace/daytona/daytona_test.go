package daytona

import (
	"context"
	"fmt"
	"io"
	"os"
	"path"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/daytona/clients/sdk-go/pkg/types"

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

func (c *fakeClient) Create(context.Context, any) (sdkSandbox, error) {
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

func (c *fakeClient) Get(_ context.Context, id string) (sdkSandbox, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	sandbox, ok := c.sandboxes[id]
	if !ok {
		return nil, os.ErrNotExist
	}
	return sandbox, nil
}

type fakeSandbox struct {
	mu      sync.Mutex
	id      string
	client  *fakeClient
	files   map[string][]byte
	deleted bool
}

func (s *fakeSandbox) ID() string { return s.id }

func (s *fakeSandbox) ExecuteCommand(context.Context, string, string, map[string]string, time.Duration) (*types.ExecuteResponse, error) {
	return &types.ExecuteResponse{ExitCode: 0, Result: "echo ok"}, nil
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
		return nil, os.ErrNotExist
	}
	return data, nil
}

func (s *fakeSandbox) GetFileInfo(_ context.Context, target string) (*types.FileInfo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if data, ok := s.files[target]; ok {
		return &types.FileInfo{Name: path.Base(target), Path: target, Size: int64(len(data))}, nil
	}
	if s.hasDir(target) {
		return &types.FileInfo{Name: path.Base(target), Path: target, IsDirectory: true}, nil
	}
	return nil, os.ErrNotExist
}

func (s *fakeSandbox) ListFiles(_ context.Context, target string) ([]*types.FileInfo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.files[target]; ok {
		return nil, os.ErrNotExist
	}
	prefix := target
	if target == "." {
		prefix = ""
	} else {
		prefix = target + "/"
	}
	seen := map[string]bool{}
	var out []*types.FileInfo
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
			out = append(out, &types.FileInfo{Name: part, Path: child, IsDirectory: true})
			continue
		}
		out = append(out, &types.FileInfo{Name: part, Path: child, Size: int64(len(data))})
	}
	if len(out) == 0 {
		return nil, os.ErrNotExist
	}
	return out, nil
}

func (s *fakeSandbox) DeleteFile(_ context.Context, target string, recursive bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.files[target]; ok {
		delete(s.files, target)
		return nil
	}
	if recursive {
		prefix := target + "/"
		for name := range s.files {
			if strings.HasPrefix(name, prefix) {
				delete(s.files, name)
			}
		}
		return nil
	}
	return os.ErrNotExist
}

func (s *fakeSandbox) Pause(context.Context) error { return nil }
func (s *fakeSandbox) Start(context.Context) error { return nil }

func (s *fakeSandbox) Delete(context.Context) error {
	s.mu.Lock()
	s.deleted = true
	s.mu.Unlock()
	s.client.mu.Lock()
	delete(s.client.sandboxes, s.id)
	s.client.mu.Unlock()
	return nil
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
