// Package conformance provides reusable checks for workspace/session
// implementations. It is evaluation tooling, not a core API.
package conformance

import (
	"context"
	"errors"
	"fmt"
	"path"
	"strings"

	"github.com/axisvela/praxo-core/adapters/workspace/contract"
	"github.com/axisvela/praxo-core/v2/pkg/sandbox"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

// Case is one workspace session expectation.
type Case struct {
	// Name labels the case in errors. Empty names get an index label.
	Name string
	// Spec is passed to Provider.Create.
	Spec contract.Spec
	// Command is passed to Session.Run.
	Command []string
	// WantExitCode is the required command exit code.
	WantExitCode int
	// WantStdoutContains checks command stdout when non-empty.
	WantStdoutContains string
	// Path is the file used for VFS and transfer checks.
	Path string
	// Content is written and compared.
	Content []byte
}

// CheckProvider creates a session, checks it, re-attaches, closes it, and
// verifies that the closed session cannot be re-attached.
func CheckProvider(ctx context.Context, provider contract.Provider, tc Case) error {
	if provider == nil {
		return errors.New("workspace/conformance: provider is nil")
	}
	if err := normalize(&tc); err != nil {
		return err
	}
	session, err := provider.Create(ctx, tc.Spec)
	if err != nil {
		return fmt.Errorf("workspace/conformance: create: %w", err)
	}
	if session == nil {
		return errors.New("workspace/conformance: create returned a nil session")
	}
	id := session.ID()
	if id == "" {
		return errors.New("workspace/conformance: empty session ID")
	}
	if err := CheckSession(ctx, session, tc); err != nil {
		_ = session.Close(ctx)
		return err
	}
	attached, err := provider.Attach(ctx, id)
	if err != nil {
		_ = session.Close(ctx)
		return fmt.Errorf("workspace/conformance: attach: %w", err)
	}
	if attached == nil || attached.ID() != id {
		_ = session.Close(ctx)
		return fmt.Errorf("workspace/conformance: attach returned %#v", attached)
	}
	if pauser, ok := session.(contract.Pauser); ok {
		if err := pauser.Pause(ctx); err != nil {
			_ = session.Close(ctx)
			return fmt.Errorf("workspace/conformance: pause: %w", err)
		}
		if err := pauser.Resume(ctx); err != nil {
			_ = session.Close(ctx)
			return fmt.Errorf("workspace/conformance: resume: %w", err)
		}
	}
	if snapshotter, ok := session.(contract.Snapshotter); ok {
		if id, err := snapshotter.Snapshot(ctx); err != nil {
			_ = session.Close(ctx)
			return fmt.Errorf("workspace/conformance: snapshot: %w", err)
		} else if id == "" {
			_ = session.Close(ctx)
			return errors.New("workspace/conformance: empty snapshot ID")
		}
	}
	if err := session.Close(ctx); err != nil {
		return fmt.Errorf("workspace/conformance: close: %w", err)
	}
	if _, err := provider.Attach(ctx, id); err == nil {
		return errors.New("workspace/conformance: attach after close succeeded")
	}
	return nil
}

// CheckSession verifies a session without creating or closing it.
func CheckSession(ctx context.Context, session contract.Session, tc Case) error {
	if session == nil {
		return errors.New("workspace/conformance: session is nil")
	}
	if err := normalize(&tc); err != nil {
		return err
	}
	if err := session.Upload(ctx, tc.Path, tc.Content); err != nil {
		return fmt.Errorf("workspace/conformance: upload: %w", err)
	}
	data, err := session.Download(ctx, tc.Path)
	if err != nil {
		return fmt.Errorf("workspace/conformance: download: %w", err)
	}
	if string(data) != string(tc.Content) {
		return fmt.Errorf("workspace/conformance: download = %q", data)
	}
	if err := session.Write(ctx, tc.Path, tc.Content); err != nil {
		return fmt.Errorf("workspace/conformance: write: %w", err)
	}
	entry, err := session.Stat(ctx, tc.Path)
	if err != nil {
		return fmt.Errorf("workspace/conformance: stat: %w", err)
	}
	if entry.IsDir || entry.Size != int64(len(tc.Content)) {
		return fmt.Errorf("workspace/conformance: stat = %#v", entry)
	}
	if _, err := session.Read(ctx, tc.Path); err != nil {
		return fmt.Errorf("workspace/conformance: read: %w", err)
	}
	entries, err := session.List(ctx, path.Dir(tc.Path))
	if err != nil {
		return fmt.Errorf("workspace/conformance: list: %w", err)
	}
	if !hasEntryName(entries, path.Base(tc.Path)) {
		return errors.New("workspace/conformance: list missing file")
	}
	paths, err := session.Glob(ctx, path.Join(path.Dir(tc.Path), "*.txt"))
	if err != nil {
		return fmt.Errorf("workspace/conformance: glob: %w", err)
	}
	if !hasPath(paths, tc.Path) {
		return errors.New("workspace/conformance: glob missing file")
	}
	matches, err := session.Grep(ctx, "conformance", path.Dir(tc.Path))
	if err != nil {
		return fmt.Errorf("workspace/conformance: grep: %w", err)
	}
	if !hasMatch(matches, path.Base(tc.Path)) {
		return errors.New("workspace/conformance: grep missing file")
	}
	result, err := session.Run(ctx, sandbox.Spec{
		Image:   tc.Spec.Image,
		WorkDir: tc.Spec.WorkDir,
		Timeout: tc.Spec.Timeout,
		Env:     tc.Spec.Env,
	}, tc.Command)
	if err != nil {
		return fmt.Errorf("workspace/conformance: run: %w", err)
	}
	if result.ExitCode != tc.WantExitCode {
		return fmt.Errorf("workspace/conformance: exit = %d, want %d", result.ExitCode, tc.WantExitCode)
	}
	if tc.WantStdoutContains != "" && !strings.Contains(result.Stdout, tc.WantStdoutContains) {
		return fmt.Errorf("workspace/conformance: stdout = %q, want substring %q", result.Stdout, tc.WantStdoutContains)
	}
	if err := session.Delete(ctx, tc.Path, false); err != nil {
		return fmt.Errorf("workspace/conformance: delete: %w", err)
	}
	if _, err := session.Stat(ctx, tc.Path); !errors.Is(err, vfs.ErrNotFound) {
		return fmt.Errorf("workspace/conformance: stat after delete = %v, want ErrNotFound", err)
	}
	return nil
}

func normalize(tc *Case) error {
	if len(tc.Command) == 0 {
		return errors.New("workspace/conformance: command is required")
	}
	if tc.Path == "" {
		tc.Path = "conformance.txt"
	}
	if tc.Content == nil {
		tc.Content = []byte("conformance")
	}
	return nil
}

func hasEntryName(entries []vfs.Entry, name string) bool {
	for _, entry := range entries {
		if entry.Name == name {
			return true
		}
	}
	return false
}

func hasPath(paths []string, want string) bool {
	for _, candidate := range paths {
		if path.Clean(candidate) == path.Clean(want) || path.Base(candidate) == path.Base(want) {
			return true
		}
	}
	return false
}

func hasMatch(matches []vfs.Match, name string) bool {
	for _, match := range matches {
		if path.Base(match.Path) == name {
			return true
		}
	}
	return false
}
