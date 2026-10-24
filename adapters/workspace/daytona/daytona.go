// Package daytona adapts Daytona sandboxes to the workspace evaluation
// contract using the Daytona Go SDK.
package daytona

import (
	"bytes"
	"context"
	"errors"
	"io"
	"os"
	"path"
	"regexp"
	"strings"
	"sync/atomic"
	"time"

	daytonasdk "github.com/daytona/clients/sdk-go/pkg/daytona"
	"github.com/daytona/clients/sdk-go/pkg/options"
	"github.com/daytona/clients/sdk-go/pkg/types"

	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

const defaultTimeout = 5 * time.Minute

// Config configures the Daytona adapter.
type Config struct {
	APIKey       string
	APIURL       string
	Target       string
	Organization string
	DefaultImage string
	Timeout      time.Duration
}

func (c Config) withDefaults() Config {
	if c.Timeout <= 0 {
		c.Timeout = defaultTimeout
	}
	return c
}

// Provider creates and attaches to Daytona sandboxes.
type Provider struct {
	client  sdkClient
	cfg     Config
	timeout time.Duration
}

// New returns a Daytona provider backed by the official Go SDK.
func New(cfg Config) (*Provider, error) {
	cfg = cfg.withDefaults()
	if cfg.APIKey == "" {
		return nil, errors.New("daytona: API key is required")
	}
	client, err := daytonasdk.NewClientWithConfig(&types.DaytonaConfig{
		APIKey:         cfg.APIKey,
		OrganizationID: cfg.Organization,
		APIUrl:         cfg.APIURL,
		Target:         cfg.Target,
	})
	if err != nil {
		return nil, err
	}
	return newProvider(&realClient{client: client}, cfg), nil
}

func newProvider(client sdkClient, cfg Config) *Provider {
	return &Provider{client: client, cfg: cfg, timeout: cfg.Timeout}
}

// Create implements contract.Provider.
func (p *Provider) Create(ctx context.Context, spec contract.Spec) (contract.Session, error) {
	params := types.ImageParams{
		SandboxBaseParams: types.SandboxBaseParams{
			EnvVars: spec.Env,
			Labels:  spec.Metadata,
		},
	}
	image := spec.Image
	if image == "" {
		image = p.cfg.DefaultImage
	}
	if image != "" {
		params.Image = image
	}
	if spec.Timeout > 0 {
		minutes := int(spec.Timeout.Minutes())
		if minutes < 1 {
			minutes = 1
		}
		params.TtlMinutes = &minutes
	}
	sandbox, err := p.client.Create(ctx, params)
	if err != nil {
		return nil, err
	}
	return &Session{box: sandbox, spec: spec}, nil
}

// Attach implements contract.Provider.
func (p *Provider) Attach(ctx context.Context, id string) (contract.Session, error) {
	sandbox, err := p.client.Get(ctx, id)
	if err != nil {
		if notFound(err) {
			return nil, contract.ErrNotFound
		}
		return nil, err
	}
	return &Session{box: sandbox}, nil
}

// Session is one Daytona sandbox.
type Session struct {
	box    sdkSandbox
	spec   contract.Spec
	closed atomic.Bool
}

// ID implements contract.Session.
func (s *Session) ID() string { return s.box.ID() }

// Run implements sandbox.Sandbox. The SDK exposes one combined output string,
// so it is returned as Stdout.
func (s *Session) Run(ctx context.Context, spec sandbox.Spec, command []string) (sandbox.Result, error) {
	if s.closed.Load() {
		return sandbox.Result{}, contract.ErrClosed
	}
	if len(command) == 0 {
		return sandbox.Result{}, errors.New("daytona: command is required")
	}
	env := spec.Env
	if len(env) == 0 {
		env = s.spec.Env
	}
	workDir := spec.WorkDir
	if workDir == "" {
		workDir = s.spec.WorkDir
	}
	response, err := s.box.ExecuteCommand(ctx, shellJoin(command), workDir, env, spec.Timeout)
	if err != nil {
		return sandbox.Result{}, err
	}
	return sandbox.Result{ExitCode: response.ExitCode, Stdout: response.Result}, nil
}

// Stat implements vfs.Backend.
func (s *Session) Stat(ctx context.Context, target string) (vfs.Entry, error) {
	if s.closed.Load() {
		return vfs.Entry{}, contract.ErrClosed
	}
	info, err := s.box.GetFileInfo(ctx, target)
	if err != nil {
		if notFound(err) {
			return vfs.Entry{}, vfs.ErrNotFound
		}
		return vfs.Entry{}, err
	}
	return entry(info), nil
}

// Read implements vfs.Backend.
func (s *Session) Read(ctx context.Context, target string) ([]byte, error) {
	if s.closed.Load() {
		return nil, contract.ErrClosed
	}
	data, err := s.box.DownloadFile(ctx, target)
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
	return s.box.UploadFile(ctx, bytes.NewReader(data), target)
}

// List implements vfs.Backend.
func (s *Session) List(ctx context.Context, target string) ([]vfs.Entry, error) {
	entries, err := s.list(ctx, target)
	if err != nil {
		return nil, err
	}
	out := make([]vfs.Entry, 0, len(entries))
	for _, item := range entries {
		out = append(out, entry(item))
	}
	return out, nil
}

// Delete implements vfs.Backend.
func (s *Session) Delete(ctx context.Context, target string, recursive bool) error {
	if s.closed.Load() {
		return contract.ErrClosed
	}
	if err := s.box.DeleteFile(ctx, target, recursive); err != nil {
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
	return s.box.Delete(ctx)
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
	return s.box.Start(ctx)
}

func (s *Session) list(ctx context.Context, target string) ([]*types.FileInfo, error) {
	entries, err := s.box.ListFiles(ctx, target)
	if err != nil {
		if notFound(err) {
			return nil, vfs.ErrNotFound
		}
		return nil, err
	}
	for _, item := range entries {
		if item.Path == "" {
			item.Path = path.Join(target, item.Name)
		}
	}
	return entries, nil
}

func (s *Session) walk(ctx context.Context, target string) ([]*types.FileInfo, error) {
	entries, err := s.list(ctx, target)
	if err != nil {
		return nil, err
	}
	var out []*types.FileInfo
	for _, item := range entries {
		if item.IsDirectory {
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

func entry(info *types.FileInfo) vfs.Entry {
	return vfs.Entry{
		Path:    info.Path,
		Name:    info.Name,
		Size:    info.Size,
		Mode:    info.Mode,
		IsDir:   info.IsDirectory,
		ModTime: info.ModifiedTime,
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
	if errors.Is(err, os.ErrNotExist) {
		return true
	}
	text := strings.ToLower(err.Error())
	return strings.Contains(text, "not found") || strings.Contains(text, "404")
}

type sdkClient interface {
	Create(ctx context.Context, params any) (sdkSandbox, error)
	Get(ctx context.Context, id string) (sdkSandbox, error)
}

type sdkSandbox interface {
	ID() string
	ExecuteCommand(ctx context.Context, command, cwd string, env map[string]string, timeout time.Duration) (*types.ExecuteResponse, error)
	UploadFile(ctx context.Context, source io.Reader, remotePath string) error
	DownloadFile(ctx context.Context, remotePath string) ([]byte, error)
	GetFileInfo(ctx context.Context, path string) (*types.FileInfo, error)
	ListFiles(ctx context.Context, path string) ([]*types.FileInfo, error)
	DeleteFile(ctx context.Context, path string, recursive bool) error
	Pause(ctx context.Context) error
	Start(ctx context.Context) error
	Delete(ctx context.Context) error
}

type realClient struct {
	client *daytonasdk.Client
}

func (c *realClient) Create(ctx context.Context, params any) (sdkSandbox, error) {
	sandbox, err := c.client.Create(ctx, params, options.WithWaitForStart(true))
	if err != nil {
		return nil, err
	}
	return realSandbox{sandbox: sandbox}, nil
}

func (c *realClient) Get(ctx context.Context, id string) (sdkSandbox, error) {
	sandbox, err := c.client.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	return realSandbox{sandbox: sandbox}, nil
}

type realSandbox struct {
	sandbox *daytonasdk.Sandbox
}

func (s realSandbox) ID() string { return s.sandbox.ID }

func (s realSandbox) ExecuteCommand(ctx context.Context, command, cwd string, env map[string]string, timeout time.Duration) (*types.ExecuteResponse, error) {
	var opts []func(*options.ExecuteCommand)
	if cwd != "" {
		opts = append(opts, options.WithCwd(cwd))
	}
	if len(env) > 0 {
		opts = append(opts, options.WithCommandEnv(env))
	}
	if timeout > 0 {
		opts = append(opts, options.WithExecuteTimeout(timeout))
	}
	return s.sandbox.Process.ExecuteCommand(ctx, command, opts...)
}

func (s realSandbox) UploadFile(ctx context.Context, source io.Reader, remotePath string) error {
	return s.sandbox.FileSystem.UploadFileStream(ctx, source, remotePath)
}

func (s realSandbox) DownloadFile(ctx context.Context, remotePath string) ([]byte, error) {
	return s.sandbox.FileSystem.DownloadFile(ctx, remotePath, nil)
}

func (s realSandbox) GetFileInfo(ctx context.Context, target string) (*types.FileInfo, error) {
	return s.sandbox.FileSystem.GetFileInfo(ctx, target)
}

func (s realSandbox) ListFiles(ctx context.Context, target string) ([]*types.FileInfo, error) {
	return s.sandbox.FileSystem.ListFiles(ctx, target, options.WithDepth(1))
}

func (s realSandbox) DeleteFile(ctx context.Context, target string, recursive bool) error {
	return s.sandbox.FileSystem.DeleteFile(ctx, target, recursive)
}

func (s realSandbox) Pause(ctx context.Context) error { return s.sandbox.Pause(ctx) }
func (s realSandbox) Start(ctx context.Context) error { return s.sandbox.Start(ctx) }
func (s realSandbox) Delete(ctx context.Context) error { return s.sandbox.Delete(ctx) }
