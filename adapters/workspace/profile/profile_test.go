package profile

import (
	"context"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

type fakeBackend struct {
	executed bool
}

func (f *fakeBackend) Stat(context.Context, string) (vfs.Entry, error) {
	return vfs.Entry{}, nil
}

func (f *fakeBackend) Read(context.Context, string) ([]byte, error) {
	return nil, nil
}

func (f *fakeBackend) Write(context.Context, string, []byte) error {
	return nil
}

func (f *fakeBackend) List(context.Context, string) ([]vfs.Entry, error) {
	return nil, nil
}

func (f *fakeBackend) Delete(context.Context, string, bool) error {
	return nil
}

func (f *fakeBackend) Glob(context.Context, string) ([]string, error) {
	return nil, nil
}

func (f *fakeBackend) Grep(context.Context, string, string) ([]vfs.Match, error) {
	return nil, nil
}

func (f *fakeBackend) Execute(context.Context, []string, string) (vfs.Result, error) {
	f.executed = true
	return vfs.Result{ExitCode: 0, Stdout: "backend"}, nil
}

type fakeExecutor struct {
	command []string
	dir     string
}

func (f *fakeExecutor) Execute(_ context.Context, command []string, dir string) (vfs.Result, error) {
	f.command = command
	f.dir = dir
	return vfs.Result{ExitCode: 0, Stdout: "executor"}, nil
}

type fakeSandbox struct {
	command []string
	spec    sandbox.Spec
}

func (f *fakeSandbox) Run(_ context.Context, spec sandbox.Spec, command []string) (sandbox.Result, error) {
	f.command = command
	f.spec = spec
	return sandbox.Result{ExitCode: 0, Stdout: "sandbox"}, nil
}

type baseSession struct {
	*fakeBackend
	*fakeSandbox
}

func (f *baseSession) ID() string {
	return "session"
}

func (f *baseSession) Upload(context.Context, string, []byte) error {
	return nil
}

func (f *baseSession) Download(context.Context, string) ([]byte, error) {
	return nil, nil
}

func (f *baseSession) Close(context.Context) error {
	return nil
}

type pauseSession struct {
	*baseSession
}

func (f *pauseSession) Pause(context.Context) error {
	return nil
}

func (f *pauseSession) Resume(context.Context) error {
	return nil
}

func (f *pauseSession) Snapshot(context.Context) (string, error) {
	return "snapshot", nil
}

func TestValidateStateRejectsExecution(t *testing.T) {
	profile := Profile{
		Kind:      KindState,
		Files:     &fakeBackend{},
		Executor:  &fakeExecutor{},
		Trust:     TrustData,
		Isolation: IsolationNone,
	}
	if err := profile.Validate(); err == nil {
		t.Fatal("state profile accepted an executor")
	}
}

func TestValidateLocalRequiresExplicitExecutor(t *testing.T) {
	without := Profile{
		Kind:      KindLocal,
		Files:     &fakeBackend{},
		Trust:     TrustHost,
		Isolation: IsolationNone,
	}
	if err := without.Validate(); err != nil {
		t.Fatalf("local profile without executor: %v", err)
	}

	with := Profile{
		Kind:         KindLocal,
		Files:        &fakeBackend{},
		Executor:     &fakeExecutor{},
		Trust:        TrustHost,
		Isolation:    IsolationNone,
		Capabilities: Capabilities{Execute: true},
	}
	if err := with.Validate(); err != nil {
		t.Fatalf("local profile with executor: %v", err)
	}

	with.Capabilities = Capabilities{}
	if err := with.Validate(); err == nil {
		t.Fatal("local profile accepted executor without execute capability")
	}
}

func TestValidateSandboxCapabilities(t *testing.T) {
	base := Profile{
		Kind:         KindSandbox,
		Files:        &fakeBackend{},
		Sandbox:      &fakeSandbox{},
		Trust:        TrustIsolated,
		Isolation:    IsolationProvider,
		Capabilities: Capabilities{Execute: true},
	}
	if err := base.Validate(); err != nil {
		t.Fatalf("sandbox profile: %v", err)
	}

	missingExecute := base
	missingExecute.Capabilities = Capabilities{}
	if err := missingExecute.Validate(); err == nil {
		t.Fatal("sandbox profile accepted without execute")
	}

	uploadWithoutSession := base
	uploadWithoutSession.Capabilities.Upload = true
	if err := uploadWithoutSession.Validate(); err == nil {
		t.Fatal("sandbox profile accepted upload without session")
	}

	noIsolation := base
	noIsolation.Isolation = IsolationNone
	if err := noIsolation.Validate(); err == nil {
		t.Fatal("sandbox profile accepted no isolation claim")
	}

	session := &pauseSession{baseSession: &baseSession{fakeBackend: &fakeBackend{}, fakeSandbox: &fakeSandbox{}}}
	withPause := base
	withPause.Session = session
	withPause.Sandbox = nil
	withPause.Capabilities = Capabilities{Execute: true, Pause: true, Snapshot: true}
	if err := withPause.Validate(); err != nil {
		t.Fatalf("sandbox profile with pauser: %v", err)
	}

	plain := &baseSession{fakeBackend: &fakeBackend{}, fakeSandbox: &fakeSandbox{}}
	withPlainPause := withPause
	withPlainPause.Session = plain
	if err := withPlainPause.Validate(); err == nil {
		t.Fatal("sandbox profile accepted pause without pauser")
	}
}

func TestStateHidesBackendExecutorTool(t *testing.T) {
	backend := &fakeBackend{}
	profile := Profile{
		Kind:      KindState,
		Files:     backend,
		Trust:     TrustData,
		Isolation: IsolationNone,
	}
	if err := profile.Validate(); err != nil {
		t.Fatalf("state profile: %v", err)
	}
	if _, ok := findTool(profile.Tools(), "fs.execute"); ok {
		t.Fatal("state profile exposed fs.execute from backend type assertion")
	}
	if backend.executed {
		t.Fatal("state backend executed")
	}
}

func TestLocalToolsExposeExecuteOnlyWhenEnabled(t *testing.T) {
	disabled := Profile{
		Kind:      KindLocal,
		Files:     &fakeBackend{},
		Trust:     TrustHost,
		Isolation: IsolationNone,
	}
	if _, ok := findTool(disabled.Tools(), "fs.execute"); ok {
		t.Fatal("local profile without executor exposed fs.execute")
	}

	executor := &fakeExecutor{}
	enabled := disabled
	enabled.Executor = executor
	enabled.Capabilities.Execute = true
	executeTool, ok := findTool(enabled.Tools(), "fs.execute")
	if !ok {
		t.Fatal("local profile with executor did not expose fs.execute")
	}
	result, err := executeTool.Invoke(context.Background(), map[string]any{
		"command": []any{"echo", "ok"},
		"dir":     "/work",
	})
	if err != nil {
		t.Fatalf("invoke: %v", err)
	}
	if len(executor.command) != 2 || executor.command[1] != "ok" || executor.dir != "/work" {
		t.Fatalf("executor got command=%v dir=%q", executor.command, executor.dir)
	}
	if result.(vfs.Result).Stdout != "executor" {
		t.Fatalf("result = %#v", result)
	}
}

func TestSandboxToolsWrapRun(t *testing.T) {
	box := &fakeSandbox{}
	profile := Profile{
		Kind:         KindSandbox,
		Files:        &fakeBackend{},
		Sandbox:      box,
		SandboxSpec:  sandbox.Spec{Image: "image"},
		Trust:        TrustIsolated,
		Isolation:    IsolationProvider,
		Capabilities: Capabilities{Execute: true},
	}
	if err := profile.Validate(); err != nil {
		t.Fatalf("sandbox profile: %v", err)
	}
	executeTool, ok := findTool(profile.Tools(), "fs.execute")
	if !ok {
		t.Fatal("sandbox profile did not expose fs.execute")
	}
	_, err := executeTool.Invoke(context.Background(), map[string]any{
		"command": []any{"echo", "ok"},
		"dir":     "/work",
	})
	if err != nil {
		t.Fatalf("invoke: %v", err)
	}
	if len(box.command) != 2 || box.command[1] != "ok" {
		t.Fatalf("sandbox command = %v", box.command)
	}
	if box.spec.Image != "image" || box.spec.WorkDir != "/work" {
		t.Fatalf("sandbox spec = %#v", box.spec)
	}
}

func TestToolsReturnNilWithoutFiles(t *testing.T) {
	if tools := (Profile{}).Tools(); tools != nil {
		t.Fatalf("tools = %#v", tools)
	}
}

func findTool(tools []tool.Tool, name string) (tool.Tool, bool) {
	for _, item := range tools {
		if item.Name() == name {
			return item, true
		}
	}
	return nil, false
}
