package profile

import (
	"context"
	"errors"
	"fmt"

	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/tool"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
	"github.com/axisvela/praxo-core/v2/pkg/vfs/vfstools"
)

type Kind string

const (
	KindState   Kind = "state"
	KindLocal   Kind = "local"
	KindSandbox Kind = "sandbox"
)

type Trust string

const (
	TrustData     Trust = "data"
	TrustHost     Trust = "host"
	TrustIsolated Trust = "isolated"
)

type Isolation string

const (
	IsolationNone      Isolation = "none"
	IsolationProcess   Isolation = "process"
	IsolationContainer Isolation = "container"
	IsolationVM        Isolation = "vm"
	IsolationProvider  Isolation = "provider"
)

type Capabilities struct {
	Execute  bool
	Upload   bool
	Download bool
	Pause    bool
	Snapshot bool
}

type Profile struct {
	Kind         Kind
	Files        vfs.Backend
	Executor     vfs.Executor
	Sandbox      sandbox.Sandbox
	Session      contract.Session
	SandboxSpec  sandbox.Spec
	Trust        Trust
	Isolation    Isolation
	Capabilities Capabilities
}

func (p Profile) Validate() error {
	if p.Files == nil {
		return errors.New("profile: files backend is required")
	}
	switch p.Kind {
	case KindState:
		return p.validateState()
	case KindLocal:
		return p.validateLocal()
	case KindSandbox:
		return p.validateSandbox()
	default:
		return fmt.Errorf("profile: unknown kind %q", p.Kind)
	}
}

func (p Profile) validateState() error {
	if p.Executor != nil || p.Sandbox != nil || p.Session != nil {
		return errors.New("profile: state does not execute commands")
	}
	if p.Trust != TrustData || p.Isolation != IsolationNone {
		return errors.New("profile: state must be data trust with no isolation")
	}
	if p.Capabilities != (Capabilities{}) {
		return errors.New("profile: state has no execution capabilities")
	}
	return nil
}

func (p Profile) validateLocal() error {
	if p.Session != nil || p.Sandbox != nil {
		return errors.New("profile: local uses executor, not sandbox or session")
	}
	if p.Trust != TrustHost || p.Isolation != IsolationNone {
		return errors.New("profile: local must be host trust with no isolation")
	}
	expected := Capabilities{Execute: p.Executor != nil}
	if p.Capabilities != expected {
		return errors.New("profile: local capabilities must match executor")
	}
	return nil
}

func (p Profile) validateSandbox() error {
	if p.Executor != nil {
		return errors.New("profile: sandbox uses sandbox or session, not executor")
	}
	if p.Trust != TrustIsolated {
		return errors.New("profile: sandbox must be isolated trust")
	}
	if p.Isolation == IsolationNone {
		return errors.New("profile: sandbox requires an isolation claim")
	}
	if p.Sandbox == nil && p.Session == nil {
		return errors.New("profile: sandbox requires sandbox or session")
	}
	if !p.Capabilities.Execute {
		return errors.New("profile: sandbox requires execute capability")
	}
	if p.Capabilities.Upload || p.Capabilities.Download {
		if p.Session == nil {
			return errors.New("profile: upload and download require a session")
		}
	}
	if p.Capabilities.Pause {
		if _, ok := p.Session.(contract.Pauser); !ok {
			return errors.New("profile: pause requires a pauser session")
		}
	}
	if p.Capabilities.Snapshot {
		if _, ok := p.Session.(contract.Snapshotter); !ok {
			return errors.New("profile: snapshot requires a snapshotter session")
		}
	}
	return nil
}

func (p Profile) Tools() ([]tool.Tool, error) {
	if err := p.Validate(); err != nil {
		return nil, err
	}
	if p.Capabilities.Execute {
		runner := p.executor()
		if runner == nil {
			return nil, errors.New("profile: execute capability requires an executor")
		}
		return vfstools.Tools(executorFiles{Backend: p.Files, executor: runner}), nil
	}
	return vfstools.Tools(filesOnly{Backend: p.Files}), nil
}

func (p Profile) executor() vfs.Executor {
	switch {
	case p.Executor != nil:
		return p.Executor
	case p.Session != nil:
		return sandboxExecutor{box: p.Session, spec: p.SandboxSpec}
	case p.Sandbox != nil:
		return sandboxExecutor{box: p.Sandbox, spec: p.SandboxSpec}
	default:
		return nil
	}
}

type filesOnly struct {
	vfs.Backend
}

type executorFiles struct {
	vfs.Backend
	executor vfs.Executor
}

func (b executorFiles) Execute(ctx context.Context, command []string, dir string) (vfs.Result, error) {
	return b.executor.Execute(ctx, command, dir)
}

type sandboxExecutor struct {
	box  sandbox.Sandbox
	spec sandbox.Spec
}

func (s sandboxExecutor) Execute(ctx context.Context, command []string, dir string) (vfs.Result, error) {
	spec := s.spec
	if dir != "" {
		spec.WorkDir = dir
	}
	result, err := s.box.Run(ctx, spec, command)
	return vfs.Result{
		ExitCode: result.ExitCode,
		Stdout:   result.Stdout,
		Stderr:   result.Stderr,
	}, err
}
