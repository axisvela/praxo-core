// Package cubesandbox adapts CubeSandbox to the workspace evaluation contract
// using the CubeSandbox Go SDK. It is an evaluation adapter, not core API.
package cubesandbox

import (
	"context"
	"errors"
	"path"
	"regexp"
	"strings"
	"sync/atomic"
	"time"

	cubesandboxsdk "github.com/tencentcloud/CubeSandbox/sdk/go"

	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

// Config configures the CubeSandbox adapter.
type Config struct {
	APIURL         string
	APIKey         string
	TemplateID     string
	MCPTemplateID  string
	ProxyNodeIP    string
	ProxyPortHTTP  int
	ProxyScheme    string
	SandboxDomain  string
	Timeout        time.Duration
	RequestTimeout time.Duration
}

// Provider creates and attaches to CubeSandbox sandboxes.
type Provider struct {
	client sdkClient
	cfg    Config
}

// New returns a CubeSandbox provider backed by the official Go SDK.
func New(cfg Config) *Provider {
	client := cubesandboxsdk.NewClient(cubesandboxsdk.Config{
		APIURL:         cfg.APIURL,
		APIKey:         cfg.APIKey,
		TemplateID:     cfg.TemplateID,
		MCPTemplateID:  cfg.MCPTemplateID,
		ProxyNodeIP:    cfg.ProxyNodeIP,
		ProxyPortHTTP:  cfg.ProxyPortHTTP,
		ProxyScheme:    cfg.ProxyScheme,
		SandboxDomain:  cfg.SandboxDomain,
		Timeout:        cfg.Timeout,
		RequestTimeout: cfg.RequestTimeout,
	})
	return newProvider(&realClient{client: client}, cfg)
}

func newProvider(client sdkClient, cfg Config) *Provider {
	return &Provider{client: client, cfg: cfg}
}

// Create implements contract.Provider.
func (p *Provider) Create(ctx context.Context, spec contract.Spec) (contract.Session, error) {
	options := cubesandboxsdk.CreateOptions{
		TemplateID: spec.Image,
		EnvVars:    spec.Env,
		Metadata:   spec.Metadata,
	}
	if options.TemplateID == "" {
		options.TemplateID = p.cfg.TemplateID
	}
	if spec.Timeout > 0 {
		timeout := spec.Timeout
		options.Timeout = &timeout
	}
	sandbox, err := p.client.Create(ctx, options)
	if err != nil {
		return nil, err
	}
	return &Session{box: sandbox, spec: spec}, nil
}

// Attach implements contract.Provider.
func (p *Provider) Attach(ctx context.Context, id string) (contract.Session, error) {
	sandbox, err := p.client.Connect(ctx, id)
	if err != nil {
		if notFound(err) {
			return nil, contract.ErrNotFound
		}
		return nil, err
	}
	return &Session{box: sandbox}, nil
}

// Session is one CubeSandbox sandbox.
type Session struct {
	box    sdkSandbox
	spec   contract.Spec
	closed atomic.Bool
}

// ID implements contract.Session.
func (s *Session) ID() string { return s.box.ID() }

// Run implements sandbox.Sandbox.
func (s *Session) Run(ctx context.Context, spec sandbox.Spec, command []string) (sandbox.Result, error) {
	if s.closed.Load() {
		return sandbox.Result{}, contract.ErrClosed
	}
	if len(command) == 0 {
		return sandbox.Result{}, errors.New("cubesandbox: command is required")
	}
	env := spec.Env
	if len(env) == 0 {
		env = s.spec.Env
	}
	cwd := spec.WorkDir
	if cwd == "" {
		cwd = s.spec.WorkDir
	}
	result, err := s.box.Run(ctx, shellJoin(command), cwd, env, spec.Timeout)
	if err != nil {
		return sandbox.Result{}, err
	}
	return sandbox.Result{ExitCode: result.ExitCode, Stdout: result.Stdout, Stderr: result.Stderr}, nil
}

// Stat implements vfs.Backend.
func (s *Session) Stat(ctx context.Context, target string) (vfs.Entry, error) {
	if s.closed.Load() {
		return vfs.Entry{}, contract.ErrClosed
	}
	entry, err := s.box.Stat(ctx, target)
	if err != nil {
		if notFound(err) {
			return vfs.Entry{}, vfs.ErrNotFound
		}
		return vfs.Entry{}, err
	}
	return mapEntry(*entry), nil
}

// Read implements vfs.Backend.
func (s *Session) Read(ctx context.Context, target string) ([]byte, error) {
	if s.closed.Load() {
		return nil, contract.ErrClosed
	}
	data, err := s.box.Read(ctx, target)
	if err != nil {
		if notFound(err) {
			return nil, vfs.ErrNotFound
		}
		return nil, err
	}
	return data, nil
}

// Write implements vfs.Backend.
func (s *Session) Write(ctx context.Context, target string, data []byte) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	return s.box.Write(ctx, target, data)
}

// List implements vfs.Backend.
func (s *Session) List(ctx context.Context, target string) ([]vfs.Entry, error) {
	entries, err := s.list(ctx, target)
	if err != nil {
		return nil, err
	}
	out := make([]vfs.Entry, 0, len(entries))
	for _, entry := range entries {
		out = append(out, mapEntry(entry))
	}
	return out, nil
}

// Delete implements vfs.Backend.
func (s *Session) Delete(ctx context.Context, target string, recursive bool) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	if recursive {
		if entries, err := s.list(ctx, target); err == nil {
			for _, entry := range entries {
				if err := s.Delete(ctx, entry.Path, true); err != nil && !errors.Is(err, vfs.ErrNotFound) {
					return err
				}
			}
		}
	}
	if err := s.box.Remove(ctx, target); err != nil {
		if notFound(err) {
			return vfs.ErrNotFound
		}
		return err
	}
	return nil
}

// Glob implements vfs.Backend.
func (s *Session) Glob(ctx context.Context, pattern string) ([]string, error) {
	entries, err := s.walk(ctx, ".")
	if err != nil {
		return nil, err
	}
	var out []string
	for _, entry := range entries {
		relative := strings.TrimPrefix(path.Clean(entry.Path), "./")
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
	for _, entry := range entries {
		data, err := s.Read(ctx, entry.Path)
		if err != nil {
			return nil, err
		}
		for index, line := range strings.Split(string(data), "\n") {
			if re.MatchString(line) {
				out = append(out, vfs.Match{Path: entry.Path, Line: index + 1, Text: line})
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
	return s.box.Kill(ctx)
}

// Pause implements contract.Pauser.
func (s *Session) Pause(ctx context.Context) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	return s.box.Pause(ctx)
}

// Resume implements contract.Pauser.
func (s *Session) Resume(ctx context.Context) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	return s.box.Resume(ctx)
}

func (s *Session) list(ctx context.Context, target string) ([]cubesandboxsdk.FileEntry, error) {
	entries, err := s.box.List(ctx, target)
	if err != nil {
		if notFound(err) {
			return nil, vfs.ErrNotFound
		}
		return nil, err
	}
	for index := range entries {
		if entries[index].Path == "" {
			entries[index].Path = path.Join(target, entries[index].Name)
		}
	}
	return entries, nil
}

func (s *Session) walk(ctx context.Context, target string) ([]cubesandboxsdk.FileEntry, error) {
	entries, err := s.list(ctx, target)
	if err != nil {
		return nil, err
	}
	var out []cubesandboxsdk.FileEntry
	for _, entry := range entries {
		if entry.IsDir() {
			children, err := s.walk(ctx, entry.Path)
			if err != nil {
				return nil, err
			}
			out = append(out, children...)
			continue
		}
		out = append(out, entry)
	}
	return out, nil
}

func mapEntry(entry cubesandboxsdk.FileEntry) vfs.Entry {
	modTime, _ := time.Parse(time.RFC3339Nano, entry.ModifiedTime)
	return vfs.Entry{
		Path:    entry.Path,
		Name:    entry.Name,
		Size:    entry.Size,
		Mode:    entry.Permissions,
		IsDir:   entry.IsDir(),
		ModTime: modTime,
	}
}

func shellJoin(args []string) string {
	out := make([]string, 0, len(args))
	for _, arg := range args {
		if arg == "" {
			out = append(out, "''")
			continue
		}
		if !strings.ContainsAny(arg, " \t\n'\"\\$`!&|;<>()*?[]{}") {
			out = append(out, arg)
			continue
		}
		out = append(out, "'"+strings.ReplaceAll(arg, "'", `'\''`)+"'")
	}
	return strings.Join(out, " ")
}

func notFound(err error) bool {
	if err == nil {
		return false
	}
	var missing *cubesandboxsdk.NotFoundError
	if errors.As(err, &missing) {
		return true
	}
	var api *cubesandboxsdk.APIError
	if errors.As(err, &api) && api.StatusCode == 404 {
		return true
	}
	text := strings.ToLower(err.Error())
	return strings.Contains(text, "not found") || strings.Contains(text, "does not exist")
}

type sdkClient interface {
	Create(ctx context.Context, options cubesandboxsdk.CreateOptions) (sdkSandbox, error)
	Connect(ctx context.Context, id string) (sdkSandbox, error)
}

type sdkSandbox interface {
	ID() string
	Run(ctx context.Context, command, cwd string, env map[string]string, timeout time.Duration) (*cubesandboxsdk.CommandResult, error)
	Stat(ctx context.Context, path string) (*cubesandboxsdk.FileEntry, error)
	List(ctx context.Context, path string) ([]cubesandboxsdk.FileEntry, error)
	Read(ctx context.Context, path string) ([]byte, error)
	Write(ctx context.Context, path string, data []byte) error
	Remove(ctx context.Context, path string) error
	Pause(ctx context.Context) error
	Resume(ctx context.Context) error
	Kill(ctx context.Context) error
}

type realClient struct {
	client *cubesandboxsdk.Client
}

func (c *realClient) Create(ctx context.Context, options cubesandboxsdk.CreateOptions) (sdkSandbox, error) {
	sandbox, err := c.client.Create(ctx, options)
	if err != nil {
		return nil, err
	}
	return realSandbox{sandbox: sandbox}, nil
}

func (c *realClient) Connect(ctx context.Context, id string) (sdkSandbox, error) {
	sandbox, err := c.client.Connect(ctx, id)
	if err != nil {
		return nil, err
	}
	return realSandbox{sandbox: sandbox}, nil
}

type realSandbox struct {
	sandbox *cubesandboxsdk.Sandbox
}

func (s realSandbox) ID() string { return s.sandbox.SandboxID }

func (s realSandbox) Run(ctx context.Context, command, cwd string, env map[string]string, timeout time.Duration) (*cubesandboxsdk.CommandResult, error) {
	return s.sandbox.Commands().Run(ctx, command, cubesandboxsdk.CommandOptions{
		Cwd:     cwd,
		Envs:    env,
		Timeout: timeout,
	})
}

func (s realSandbox) Stat(ctx context.Context, target string) (*cubesandboxsdk.FileEntry, error) {
	return s.sandbox.Files().Stat(ctx, target)
}

func (s realSandbox) List(ctx context.Context, target string) ([]cubesandboxsdk.FileEntry, error) {
	return s.sandbox.Files().List(ctx, target)
}

func (s realSandbox) Read(ctx context.Context, target string) ([]byte, error) {
	text, err := s.sandbox.Files().Read(ctx, target)
	if err != nil {
		return nil, err
	}
	return []byte(text), nil
}

func (s realSandbox) Write(ctx context.Context, target string, data []byte) error {
	return s.sandbox.Files().Write(ctx, target, data)
}

func (s realSandbox) Remove(ctx context.Context, target string) error {
	return s.sandbox.Files().Remove(ctx, target)
}

func (s realSandbox) Pause(ctx context.Context) error {
	return s.sandbox.Pause(ctx, cubesandboxsdk.PauseOptions{})
}

func (s realSandbox) Resume(ctx context.Context) error {
	return s.sandbox.Resume(ctx, nil)
}

func (s realSandbox) Kill(ctx context.Context) error {
	return s.sandbox.Kill(ctx)
}
