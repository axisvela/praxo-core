package e2b

import (
	"context"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"path"
	"strings"
	"sync"
	"testing"

	"github.com/axisvela/praxo-core/adapters/workspace/conformance"
)

func TestProviderConformance(t *testing.T) {
	server := newFakeServer()
	provider, err := New(Config{
		APIKey:      "test-key",
		PlatformURL: server.URL,
		EnvdURL:     server.URL,
	})
	if err != nil {
		t.Fatal(err)
	}
	err = conformance.CheckProvider(context.Background(), provider, conformance.Case{
		Command:            []string{"echo", "ok"},
		WantStdoutContains: "echo ok",
		Path:               "nested/file.txt",
		Content:            []byte("conformance"),
	})
	if err != nil {
		t.Fatal(err)
	}
}

type fakeServer struct {
	*httptest.Server
	mu     sync.Mutex
	closed bool
	files  map[string][]byte
}

func newFakeServer() *fakeServer {
	fake := &fakeServer{files: map[string][]byte{}}
	fake.Server = httptest.NewServer(http.HandlerFunc(fake.handle))
	return fake
}

func (f *fakeServer) handle(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if strings.HasPrefix(r.URL.Path, "/v2/sandboxes") {
		f.handlePlatform(w, r)
		return
	}
	if r.Header.Get("E2b-Sandbox-Id") != "sbx-1" || r.Header.Get("X-Access-Token") != "token" {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	f.handleEnvd(w, r)
}

func (f *fakeServer) handlePlatform(w http.ResponseWriter, r *http.Request) {
	switch {
	case r.Method == http.MethodPost && r.URL.Path == "/v2/sandboxes":
		w.WriteHeader(http.StatusCreated)
		fmt.Fprint(w, `{"sandboxID":"sbx-1","envdAccessToken":"token"}`)
	case r.Method == http.MethodPost && r.URL.Path == "/v2/sandboxes/sbx-1/connect":
		if f.closed {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		fmt.Fprint(w, `{"sandboxID":"sbx-1","envdAccessToken":"token"}`)
	case r.Method == http.MethodPost && (r.URL.Path == "/v2/sandboxes/sbx-1/pause" || r.URL.Path == "/v2/sandboxes/sbx-1/resume"):
		fmt.Fprint(w, `{}`)
	case r.Method == http.MethodDelete && r.URL.Path == "/v2/sandboxes/sbx-1":
		f.closed = true
		w.WriteHeader(http.StatusNoContent)
	default:
		http.NotFound(w, r)
	}
}

func (f *fakeServer) handleEnvd(w http.ResponseWriter, r *http.Request) {
	switch r.URL.Path {
	case "/filesystem.Filesystem/Stat":
		var request struct {
			Path string `json:"path"`
		}
		decodeBody(r, &request)
		entry, ok := f.stat(request.Path)
		if !ok {
			http.Error(w, `{"code":"not_found"}`, http.StatusNotFound)
			return
		}
		writeJSON(w, map[string]any{"entry": entry})
	case "/filesystem.Filesystem/ListDir":
		var request struct {
			Path string `json:"path"`
		}
		decodeBody(r, &request)
		entries, ok := f.list(request.Path)
		if !ok {
			http.Error(w, `{"code":"invalid_argument"}`, http.StatusBadRequest)
			return
		}
		writeJSON(w, map[string]any{"entries": entries})
	case "/filesystem.Filesystem/Remove":
		var request struct {
			Path string `json:"path"`
		}
		decodeBody(r, &request)
		f.remove(request.Path)
		writeJSON(w, map[string]any{})
	case "/files":
		f.handleFile(w, r)
	case "/process.Process/Start":
		f.handleProcess(w)
	default:
		http.NotFound(w, r)
	}
}

func (f *fakeServer) handleFile(w http.ResponseWriter, r *http.Request) {
	target := r.URL.Query().Get("path")
	switch r.Method {
	case http.MethodGet:
		data, ok := f.files[target]
		if !ok {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write(data)
	case http.MethodPost:
		data, _ := io.ReadAll(r.Body)
		f.files[target] = data
		w.WriteHeader(http.StatusOK)
	default:
		http.Error(w, "method", http.StatusMethodNotAllowed)
	}
}

func (f *fakeServer) handleProcess(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/connect+json")
	writeFrame(w, 0, map[string]any{"event": map[string]any{"data": map[string]any{
		"stdout": base64.StdEncoding.EncodeToString([]byte("echo ok")),
	}}})
	writeFrame(w, 0, map[string]any{"event": map[string]any{"end": map[string]any{
		"exitCode": 0, "exited": true,
	}}})
	writeFrame(w, 2, map[string]any{})
}

func writeFrame(w io.Writer, flags byte, payload any) {
	raw, _ := json.Marshal(payload)
	header := make([]byte, 5)
	header[0] = flags
	binary.BigEndian.PutUint32(header[1:], uint32(len(raw)))
	_, _ = w.Write(header)
	_, _ = w.Write(raw)
}

func (f *fakeServer) stat(target string) (map[string]any, bool) {
	if data, ok := f.files[target]; ok {
		return map[string]any{
			"name": path.Base(target),
			"path": target,
			"type": "FILE_TYPE_FILE",
			"size": len(data),
		}, true
	}
	if f.hasDir(target) {
		return map[string]any{
			"name": path.Base(target),
			"path": target,
			"type": "FILE_TYPE_DIRECTORY",
			"size": 0,
		}, true
	}
	return nil, false
}

func (f *fakeServer) list(target string) ([]map[string]any, bool) {
	if _, ok := f.files[target]; ok {
		return nil, false
	}
	prefix := target
	if target == "." {
		prefix = ""
	} else {
		prefix = target + "/"
	}
	seen := map[string]bool{}
	var out []map[string]any
	for name, data := range f.files {
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
			out = append(out, map[string]any{"name": part, "path": child, "type": "FILE_TYPE_DIRECTORY"})
			continue
		}
		out = append(out, map[string]any{
			"name": part,
			"path": child,
			"type": "FILE_TYPE_FILE",
			"size": len(data),
		})
	}
	if len(out) == 0 {
		return nil, false
	}
	return out, true
}

func (f *fakeServer) hasDir(target string) bool {
	if target == "." {
		return len(f.files) > 0
	}
	prefix := target + "/"
	for name := range f.files {
		if strings.HasPrefix(name, prefix) {
			return true
		}
	}
	return false
}

func (f *fakeServer) remove(target string) {
	delete(f.files, target)
	prefix := target + "/"
	for name := range f.files {
		if strings.HasPrefix(name, prefix) {
			delete(f.files, name)
		}
	}
}

func decodeBody(r *http.Request, out any) {
	_ = json.NewDecoder(r.Body).Decode(out)
}

func writeJSON(w http.ResponseWriter, value any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(value)
}
