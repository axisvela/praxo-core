// Package opensandbox adapts OpenSandbox to the workspace evaluation contract
// using the OpenSandbox Go SDK. It is an evaluation adapter, not core API.
package opensandbox

import (
	"context"
	"errors"
	"fmt"
	"io"
	"path"
	"regexp"
	"strings"
	"sync/atomic"
	"time"

	opensandboxsdk "github.com/alibaba/OpenSandbox/sdks/sandbox/go"

	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

// Config configures the OpenSandbox adapter.
type Config struct {
	Domain         string
	Protocol       string
	APIKey         string
	AuthHeader     string
	UseServerProxy bool
	Timeout        time.Duration
	DefaultImage   string
}

// Provider creates and attaches to OpenSandbox sandboxes.
type Provider struct {
	client sdkClient
	cfg    Config
}

// New returns an OpenSandbox provider backed by the official Go SDK.
func New(cfg Config) *Provider {
	connection := opensandboxsdk.ConnectionConfig{
		Domain:         cfg.Domain,
		Protocol:       cfg.Protocol,
		APIKey:         cfg.APIKey,
		AuthHeader:     cfg.AuthHeader,
		UseServerProxy: cfg.UseServerProxy,
		RequestTimeout: cfg.Timeout,
	}
	return newProvider(&realClient{config: connection}, cfg)
}

func newProvider(client sdkClient, cfg Config) *Provider {
	return &Provider{client: client, cfg: cfg}
}

// Create implements contract.Provider.
func (p *Provider) Create(ctx context.Context, spec contract.Spec) (contract.Session, error) {
	image := spec.Image
	if image == "" {
		image = p.cfg.DefaultImage
	}
	options := opensandboxsdk.SandboxCreateOptions{
		Image:    image,
		Env:      spec.Env,
		Metadata: spec.Metadata,
	}
	if spec.Timeout > 0 {
		seconds := int(spec.Timeout.Seconds())
		if seconds < 1 {
			seconds = 1
		}
		options.TimeoutSeconds = &seconds
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

// Session is one OpenSandbox sandbox.
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
		return sandbox.Result{}, errors.New("opensandbox: command is required")
	}
	env := spec.Env
	if len(env) == 0 {
		env = s.spec.Env
	}
	cwd := spec.WorkDir
	if cwd == "" {
		cwd = s.spec.WorkDir
	}
	request := opensandboxsdk.RunCommandRequest{
		Command: shellJoin(command),
		Cwd:     cwd,
		Envs:    env,
	}
	if spec.Timeout > 0 {
		request.Timeout = spec.Timeout.Milliseconds()
	}
	execution, err := s.box.RunCommand(ctx, request)
	if err != nil {
		return sandbox.Result{}, err
	}
	if execution.Error != nil {
		return sandbox.Result{}, fmt.Errorf("opensandbox: %s: %s", execution.Error.Name, execution.Error.Value)
	}
	exitCode := 0
	if execution.ExitCode != nil {
		exitCode = *execution.ExitCode
	}
	return sandbox.Result{
		ExitCode: exitCode,
		Stdout:   joinMessages(execution.Stdout),
		Stderr:   joinMessages(execution.Stderr),
	}, nil
}

func joinMessages(messages []opensandboxsdk.OutputMessage) string {
	var builder strings.Builder
	for _, message := range messages {
		builder.WriteString(message.Text)
	}
	return builder.String()
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
	return mapEntry(*info), nil
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
	return s.box.UploadFile(ctx, strings.NewReader(string(data)), target)
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
	if err := s.box.Delete(ctx, target, recursive); err != nil {
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

func (s *Session) list(ctx context.Context, target string) ([]opensandboxsdk.FileInfo, error) {
	entries, err := s.box.ListDirectory(ctx, target)
	if err != nil {
		if notFound(err) {
			return nil, vfs.ErrNotFound
		}
		return nil, err
	}
	for index := range entries {
		if entries[index].Path == "" {
			entries[index].Path = target
		}
	}
	return entries, nil
}

func (s *Session) walk(ctx context.Context, target string) ([]opensandboxsdk.FileInfo, error) {
	entries, err := s.list(ctx, target)
	if err != nil {
		return nil, err
	}
	var out []opensandboxsdk.FileInfo
	for _, entry := range entries {
		if isDir(entry) {
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

func mapEntry(info opensandboxsdk.FileInfo) vfs.Entry {
	return vfs.Entry{
		Path:    info.Path,
		Name:    path.Base(info.Path),
		Size:    info.Size,
		IsDir:   isDir(info),
		ModTime: info.ModifiedAt,
	}
}

func isDir(info opensandboxsdk.FileInfo) bool {
	value := strings.ToLower(info.Type)
	return strings.Contains(value, "dir")
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
	var api *opensandboxsdk.APIError
	if errors.As(err, &api) && api.StatusCode == 404 {
		return true
	}
	text := strings.ToLower(err.Error())
	return strings.Contains(text, "not found") || strings.Contains(text, "404")
}

type sdkClient interface {
	Create(ctx context.Context, options opensandboxsdk.SandboxCreateOptions) (sdkSandbox, error)
	Connect(ctx context.Context, id string) (sdkSandbox, error)
}

type sdkSandbox interface {
	ID() string
	RunCommand(ctx context.Context, request opensandboxsdk.RunCommandRequest) (*opensandboxsdk.Execution, error)
	GetFileInfo(ctx context.Context, path string) (*opensandboxsdk.FileInfo, error)
	ListDirectory(ctx context.Context, path string) ([]opensandboxsdk.FileInfo, error)
	UploadFile(ctx context.Context, source io.Reader, remotePath string) error
	DownloadFile(ctx context.Context, remotePath string) ([]byte, error)
	Delete(ctx context.Context, path string, recursive bool) error
	Pause(ctx context.Context) error
	Resume(ctx context.Context) error
	Kill(ctx context.Context) error
}

type realClient struct {
	config opensandboxsdk.ConnectionConfig
}

func (c *realClient) Create(ctx context.Context, options opensandboxsdk.SandboxCreateOptions) (sdkSandbox, error) {
	sandbox, err := opensandboxsdk.CreateSandbox(ctx, c.config, options)
	if err != nil {
		return nil, err
	}
	return realSandbox{sandbox: sandbox}, nil
}

func (c *realClient) Connect(ctx context.Context, id string) (sdkSandbox, error) {
	sandbox, err := opensandboxsdk.ConnectSandbox(ctx, c.config, id)
	if err != nil {
		return nil, err
	}
	return realSandbox{sandbox: sandbox}, nil
}

type realSandbox struct {
	sandbox *opensandboxsdk.Sandbox
}

func (s realSandbox) ID() string { return s.sandbox.ID() }

func (s realSandbox) RunCommand(ctx context.Context, request opensandboxsdk.RunCommandRequest) (*opensandboxsdk.Execution, error) {
	return s.sandbox.RunCommandWithOpts(ctx, request, nil)
}

func (s realSandbox) GetFileInfo(ctx context.Context, target string) (*opensandboxsdk.FileInfo, error) {
	result, err := s.sandbox.GetFileInfo(ctx, target)
	if err != nil {
		return nil, err
	}
	for _, info := range result {
		return &info, nil
	}
	return nil, &opensandboxsdk.APIError{StatusCode: 404}
}

func (s realSandbox) ListDirectory(ctx context.Context, target string) ([]opensandboxsdk.FileInfo, error) {
	return s.sandbox.ListDirectory(ctx, target)
}

func (s realSandbox) UploadFile(ctx context.Context, source io.Reader, remotePath string) error {
	return s.sandbox.UploadFile(ctx, source, opensandboxsdk.UploadFileOptions{
		FileName: path.Base(remotePath),
		Metadata: opensandboxsdk.FileMetadata{Path: remotePath},
	})
}

func (s realSandbox) DownloadFile(ctx context.Context, remotePath string) ([]byte, error) {
	reader, err := s.sandbox.DownloadFile(ctx, remotePath, "", opensandboxsdk.DownloadFileOptions{})
	if err != nil {
		return nil, err
	}
	defer reader.Close()
	return io.ReadAll(reader)
}

func (s realSandbox) Delete(ctx context.Context, target string, recursive bool) error {
	if recursive {
		if err := s.sandbox.DeleteDirectory(ctx, target); err == nil {
			return nil
		}
	}
	return s.sandbox.DeleteFiles(ctx, []string{target})
}

func (s realSandbox) Pause(ctx context.Context) error {
	return s.sandbox.Pause(ctx)
}

func (s realSandbox) Resume(ctx context.Context) error {
	_, err := s.sandbox.Resume(ctx)
	return err
}

func (s realSandbox) Kill(ctx context.Context) error {
	return s.sandbox.Kill(ctx)
}
