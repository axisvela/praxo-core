// Package e2b adapts E2B sandboxes to the workspace evaluation contract.
// It uses the E2B platform REST API and the envd Connect/JSON endpoints.
package e2b

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
	"regexp"
	"strconv"
	"strings"
	"sync/atomic"
	"time"

	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

const (
	defaultPlatformURL = "https://api.e2b.app"
	defaultEnvdURL     = "https://sandbox.e2b.app"
	defaultTemplate    = "base"
	defaultEnvdPort    = 49983
	defaultTimeout     = 300 * time.Second
)

// Config configures the E2B adapter.
type Config struct {
	APIKey          string
	PlatformURL     string
	EnvdURL         string
	HTTP            *http.Client
	DefaultTemplate string
	EnvdPort        int
	Timeout         time.Duration
}

func (c Config) withDefaults() Config {
	if c.PlatformURL == "" {
		c.PlatformURL = defaultPlatformURL
	}
	if c.EnvdURL == "" {
		c.EnvdURL = defaultEnvdURL
	}
	if c.HTTP == nil {
		c.HTTP = &http.Client{Timeout: 120 * time.Second}
	}
	if c.DefaultTemplate == "" {
		c.DefaultTemplate = defaultTemplate
	}
	if c.EnvdPort <= 0 {
		c.EnvdPort = defaultEnvdPort
	}
	if c.Timeout <= 0 {
		c.Timeout = defaultTimeout
	}
	return c
}

// Provider creates and attaches to E2B sandboxes.
type Provider struct {
	cfg  Config
	http *http.Client
}

// New returns an E2B provider.
func New(cfg Config) (*Provider, error) {
	cfg = cfg.withDefaults()
	if cfg.APIKey == "" {
		return nil, errors.New("e2b: API key is required")
	}
	return &Provider{cfg: cfg, http: cfg.HTTP}, nil
}

// Create implements contract.Provider.
func (p *Provider) Create(ctx context.Context, spec contract.Spec) (contract.Session, error) {
	body := map[string]any{"templateID": p.template(spec)}
	timeout := p.timeout(spec.Timeout)
	body["timeout"] = int(timeout.Seconds())
	if len(spec.Env) > 0 {
		body["envVars"] = spec.Env
	}
	if len(spec.Metadata) > 0 {
		body["metadata"] = spec.Metadata
	}
	var response sandboxInfo
	if err := p.platform(ctx, http.MethodPost, "/v2/sandboxes", body, &response); err != nil {
		return nil, err
	}
	return p.session(response, spec)
}

// Attach implements contract.Provider.
func (p *Provider) Attach(ctx context.Context, id string) (contract.Session, error) {
	var response sandboxInfo
	body := map[string]any{"timeout": int(p.cfg.Timeout.Seconds())}
	if err := p.platform(ctx, http.MethodPost, "/v2/sandboxes/"+url.PathEscape(id)+"/connect", body, &response); err != nil {
		return nil, err
	}
	return p.session(response, contract.Spec{})
}

func (p *Provider) session(info sandboxInfo, spec contract.Spec) (contract.Session, error) {
	if info.SandboxID == "" {
		return nil, errors.New("e2b: create response is missing sandboxID")
	}
	if info.EnvdAccessToken == "" {
		return nil, errors.New("e2b: create response is missing envdAccessToken")
	}
	return &Session{
		id:    info.SandboxID,
		token: info.EnvdAccessToken,
		cfg:   p.cfg,
		http:  p.http,
		spec:  spec,
	}, nil
}

func (p *Provider) template(spec contract.Spec) string {
	if spec.Image != "" {
		return spec.Image
	}
	return p.cfg.DefaultTemplate
}

func (p *Provider) timeout(value time.Duration) time.Duration {
	if value > 0 {
		return value
	}
	return p.cfg.Timeout
}

type sandboxInfo struct {
	SandboxID       string `json:"sandboxID"`
	EnvdAccessToken string `json:"envdAccessToken"`
}

// Session is one E2B sandbox.
type Session struct {
	id     string
	token  string
	cfg    Config
	http   *http.Client
	spec   contract.Spec
	closed atomic.Bool
}

// ID implements contract.Session.
func (s *Session) ID() string { return s.id }

// Run implements sandbox.Sandbox.
func (s *Session) Run(ctx context.Context, spec sandbox.Spec, command []string) (sandbox.Result, error) {
	if s.closed.Load() {
		return sandbox.Result{}, contract.ErrClosed
	}
	if len(command) == 0 {
		return sandbox.Result{}, errors.New("e2b: command is required")
	}
	envs := spec.Env
	if len(envs) == 0 {
		envs = s.spec.Env
	}
	workDir := spec.WorkDir
	if workDir == "" {
		workDir = s.spec.WorkDir
	}
	payload := map[string]any{
		"process": map[string]any{
			"cmd":  command[0],
			"args": command[1:],
			"envs": envs,
			"cwd":  workDir,
		},
		"stdin": false,
	}
	frame, err := connectFrame(payload)
	if err != nil {
		return sandbox.Result{}, err
	}
	headers := s.envdHeaders()
	headers.Set("Content-Type", "application/connect+json")
	headers.Set("Connect-Protocol-Version", "1")
	if spec.Timeout > 0 {
		headers.Set("Connect-Timeout-Ms", strconv.FormatInt(spec.Timeout.Milliseconds(), 10))
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, s.cfg.EnvdURL+"/process.Process/Start", bytes.NewReader(frame))
	if err != nil {
		return sandbox.Result{}, err
	}
	request.Header = headers
	response, err := s.http.Do(request)
	if err != nil {
		return sandbox.Result{}, err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 1<<20))
		return sandbox.Result{}, fmt.Errorf("e2b: process start: %s: %s", response.Status, strings.TrimSpace(string(body)))
	}
	result, err := decodeProcess(response.Body)
	if err != nil {
		return sandbox.Result{}, err
	}
	return result, nil
}

func connectFrame(payload any) ([]byte, error) {
	raw, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}
	frame := make([]byte, 5+len(raw))
	frame[0] = 0
	binary.BigEndian.PutUint32(frame[1:5], uint32(len(raw)))
	copy(frame[5:], raw)
	return frame, nil
}

func decodeProcess(reader io.Reader) (sandbox.Result, error) {
	result := sandbox.Result{}
	started := false
	ended := false
	for {
		header := make([]byte, 5)
		if _, err := io.ReadFull(reader, header); err != nil {
			if errors.Is(err, io.EOF) || errors.Is(err, io.ErrUnexpectedEOF) {
				break
			}
			return sandbox.Result{}, err
		}
		flags := header[0]
		length := binary.BigEndian.Uint32(header[1:5])
		payload := make([]byte, length)
		if _, err := io.ReadFull(reader, payload); err != nil {
			return sandbox.Result{}, err
		}
		var message struct {
			Event *struct {
				Data *struct {
					Stdout string `json:"stdout"`
					Stderr string `json:"stderr"`
				} `json:"data"`
				End *struct {
					ExitCode int     `json:"exitCode"`
					Exited   bool    `json:"exited"`
					Error    *string `json:"error"`
				} `json:"end"`
			} `json:"event"`
			Error *struct {
				Code    string `json:"code"`
				Message string `json:"message"`
			} `json:"error"`
		}
		if err := json.Unmarshal(payload, &message); err != nil {
			return sandbox.Result{}, err
		}
		if message.Error != nil {
			return sandbox.Result{}, fmt.Errorf("e2b: %s: %s", message.Error.Code, message.Error.Message)
		}
		if message.Event != nil {
			if message.Event.Data != nil {
				if text, err := decodeText(message.Event.Data.Stdout); err == nil {
					result.Stdout += text
				}
				if text, err := decodeText(message.Event.Data.Stderr); err == nil {
					result.Stderr += text
				}
			}
			if message.Event.End != nil {
				started = true
				ended = true
				result.ExitCode = message.Event.End.ExitCode
				if message.Event.End.Error != nil {
					return sandbox.Result{}, fmt.Errorf("e2b: %s", *message.Event.End.Error)
				}
			}
		}
		if flags&2 != 0 {
			break
		}
	}
	if !started && !ended {
		return sandbox.Result{}, errors.New("e2b: process stream ended without a result")
	}
	return result, nil
}

func decodeText(value string) (string, error) {
	if value == "" {
		return "", nil
	}
	raw, err := base64.StdEncoding.DecodeString(value)
	if err != nil {
		return "", err
	}
	return string(raw), nil
}

// Stat implements vfs.Backend.
func (s *Session) Stat(ctx context.Context, target string) (vfs.Entry, error) {
	var response struct {
		Entry entryInfo `json:"entry"`
	}
	if err := s.envdJSON(ctx, "/filesystem.Filesystem/Stat", map[string]any{"path": target}, &response); err != nil {
		return vfs.Entry{}, err
	}
	return response.Entry.entry(target), nil
}

// Read implements vfs.Backend.
func (s *Session) Read(ctx context.Context, target string) ([]byte, error) {
	if s.closed.Load() {
		return nil, contract.ErrClosed
	}
	query := url.Values{"path": []string{target}}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, s.cfg.EnvdURL+"/files?"+query.Encode(), nil)
	if err != nil {
		return nil, err
	}
	request.Header = s.envdHeaders()
	response, err := s.http.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	if response.StatusCode == http.StatusNotFound {
		return nil, vfs.ErrNotFound
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 1<<20))
		return nil, fmt.Errorf("e2b: download: %s: %s", response.Status, strings.TrimSpace(string(body)))
	}
	return io.ReadAll(response.Body)
}

// Write implements vfs.Backend.
func (s *Session) Write(ctx context.Context, target string, data []byte) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	query := url.Values{"path": []string{target}}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, s.cfg.EnvdURL+"/files?"+query.Encode(), bytes.NewReader(data))
	if err != nil {
		return err
	}
	request.Header = s.envdHeaders()
	request.Header.Set("Content-Type", "application/octet-stream")
	response, err := s.http.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(response.Body, 1<<20))
		return fmt.Errorf("e2b: upload: %s: %s", response.Status, strings.TrimSpace(string(body)))
	}
	return nil
}

// List implements vfs.Backend.
func (s *Session) List(ctx context.Context, target string) ([]vfs.Entry, error) {
	entries, err := s.listEntries(ctx, target)
	if err != nil {
		return nil, err
	}
	out := make([]vfs.Entry, 0, len(entries))
	for _, item := range entries {
		out = append(out, item.entry(item.Path))
	}
	return out, nil
}

// Delete implements vfs.Backend.
func (s *Session) Delete(ctx context.Context, target string, recursive bool) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	if recursive {
		if entries, err := s.listEntries(ctx, target); err == nil {
			for _, item := range entries {
				if err := s.Delete(ctx, item.Path, true); err != nil && !errors.Is(err, vfs.ErrNotFound) {
					return err
				}
			}
		}
	}
	return s.envdJSON(ctx, "/filesystem.Filesystem/Remove", map[string]any{"path": target}, nil)
}

// Glob implements vfs.Backend.
func (s *Session) Glob(ctx context.Context, pattern string) ([]string, error) {
	entries, err := s.walk(ctx, ".")
	if err != nil {
		return nil, err
	}
	var out []string
	for _, item := range entries {
		relative := strings.TrimPrefix(path.Clean(item.Path), "./")
		ok, err := path.Match(pattern, relative)
		if err != nil {
			return nil, err
		}
		if ok {
			out = append(out, relative)
		}
	}
	return out, nil
}

// Grep implements vfs.Backend.
func (s *Session) Grep(ctx context.Context, pattern, target string) ([]vfs.Match, error) {
	re, err := regexp.Compile(pattern)
	if err != nil {
		return nil, err
	}
	entries, err := s.walk(ctx, target)
	if err != nil {
		return nil, err
	}
	var out []vfs.Match
	for _, item := range entries {
		data, err := s.Read(ctx, item.Path)
		if err != nil {
			return nil, err
		}
		for index, line := range strings.Split(string(data), "\n") {
			if re.MatchString(line) {
				out = append(out, vfs.Match{Path: item.Path, Line: index + 1, Text: line})
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
func (s *Session) Close(ctx context.Context) error {
	if s.closed.Swap(true) {
		return nil
	}
	return s.platform(ctx, http.MethodDelete, "/v2/sandboxes/"+url.PathEscape(s.id), nil, nil)
}

// Pause implements contract.Pauser.
func (s *Session) Pause(ctx context.Context) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	return s.platform(ctx, http.MethodPost, "/v2/sandboxes/"+url.PathEscape(s.id)+"/pause", nil, nil)
}

// Resume implements contract.Pauser.
func (s *Session) Resume(ctx context.Context) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	return s.platform(ctx, http.MethodPost, "/v2/sandboxes/"+url.PathEscape(s.id)+"/resume", nil, nil)
}

func (s *Session) listEntries(ctx context.Context, target string) ([]entryInfo, error) {
	var response struct {
		Entries []entryInfo `json:"entries"`
	}
	if err := s.envdJSON(ctx, "/filesystem.Filesystem/ListDir", map[string]any{"path": target, "depth": 1}, &response); err != nil {
		return nil, err
	}
	for index := range response.Entries {
		response.Entries[index].Path = path.Join(target, response.Entries[index].Name)
	}
	return response.Entries, nil
}

func (s *Session) walk(ctx context.Context, target string) ([]entryInfo, error) {
	entries, err := s.listEntries(ctx, target)
	if err != nil {
		return nil, err
	}
	var out []entryInfo
	for _, item := range entries {
		if item.isDir() {
			children, err := s.walk(ctx, item.Path)
			if err != nil {
				return nil, err
			}
			out = append(out, children...)
			continue
		}
		out = append(out, item)
	}
	return out, nil
}

func (s *Session) platform(ctx context.Context, method, endpoint string, body, out any) error {
	var reader io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(raw)
	}
	request, err := http.NewRequestWithContext(ctx, method, s.cfg.PlatformURL+endpoint, reader)
	if err != nil {
		return err
	}
	request.Header.Set("X-API-Key", s.cfg.APIKey)
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
	}
	response, err := s.http.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	payload, err := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if err != nil {
		return err
	}
	if response.StatusCode == http.StatusNotFound {
		return contract.ErrNotFound
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("e2b: %s: %s", response.Status, strings.TrimSpace(string(payload)))
	}
	if out == nil || len(payload) == 0 {
		return nil
	}
	return json.Unmarshal(payload, out)
}

func (s *Session) envdJSON(ctx context.Context, endpoint string, body, out any) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, s.cfg.EnvdURL+endpoint, bytes.NewReader(raw))
	if err != nil {
		return err
	}
	request.Header = s.envdHeaders()
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Connect-Protocol-Version", "1")
	response, err := s.http.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	payload, err := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if err != nil {
		return err
	}
	if response.StatusCode == http.StatusNotFound {
		return vfs.ErrNotFound
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("e2b: %s: %s", response.Status, strings.TrimSpace(string(payload)))
	}
	if out == nil || len(payload) == 0 {
		return nil
	}
	return json.Unmarshal(payload, out)
}

func (s *Session) envdHeaders() http.Header {
	headers := http.Header{}
	headers.Set("E2b-Sandbox-Id", s.id)
	headers.Set("E2b-Sandbox-Port", strconv.Itoa(s.cfg.EnvdPort))
	headers.Set("X-Access-Token", s.token)
	return headers
}

func (p *Provider) platform(ctx context.Context, method, endpoint string, body, out any) error {
	var reader io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			return err
		}
		reader = bytes.NewReader(raw)
	}
	request, err := http.NewRequestWithContext(ctx, method, p.cfg.PlatformURL+endpoint, reader)
	if err != nil {
		return err
	}
	request.Header.Set("X-API-Key", p.cfg.APIKey)
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
	}
	response, err := p.http.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	payload, err := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if err != nil {
		return err
	}
	if response.StatusCode == http.StatusNotFound {
		return contract.ErrNotFound
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("e2b: %s: %s", response.Status, strings.TrimSpace(string(payload)))
	}
	if out == nil || len(payload) == 0 {
		return nil
	}
	return json.Unmarshal(payload, out)
}

type entryInfo struct {
	Name         string          `json:"name"`
	Path         string          `json:"path"`
	Type         string          `json:"type"`
	Size         json.RawMessage `json:"size"`
	ModifiedTime string          `json:"modifiedTime"`
}

func (e entryInfo) isDir() bool {
	return e.Type == "FILE_TYPE_DIRECTORY" || e.Type == "directory"
}

func (e entryInfo) entry(target string) vfs.Entry {
	if target == "" {
		target = e.Path
	}
	if target == "" {
		target = e.Name
	}
	size := int64(0)
	if len(e.Size) > 0 {
		var number json.Number
		if err := json.Unmarshal(e.Size, &number); err == nil {
			size, _ = number.Int64()
		} else {
			var text string
			if err := json.Unmarshal(e.Size, &text); err == nil {
				size, _ = strconv.ParseInt(text, 10, 64)
			}
		}
	}
	modTime := time.Time{}
	if e.ModifiedTime != "" {
		modTime, _ = time.Parse(time.RFC3339Nano, e.ModifiedTime)
	}
	return vfs.Entry{
		Path:    target,
		Name:    e.Name,
		Size:    size,
		IsDir:   e.isDir(),
		ModTime: modTime,
	}
}
