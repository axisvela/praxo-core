// Package localfs implements the vfs.Backend contract over a confined local
// directory. All paths are virtual and relative to the backend root.
package localfs

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/policy"
	"github.com/axisvela/praxo-core/v2/pkg/vfs"
)

// Backend is a local-directory vfs.Backend confined to Root.
type Backend struct {
	root    string
	checker *policy.PathChecker
}

// New creates a local backend rooted at root. The root is created when absent.
func New(root string) (*Backend, error) {
	if strings.TrimSpace(root) == "" {
		return nil, errors.New("vfs/localfs: root is required")
	}
	abs, err := filepath.Abs(root)
	if err != nil {
		return nil, fmt.Errorf("vfs/localfs: root: %w", err)
	}
	if err := os.MkdirAll(abs, 0o700); err != nil {
		return nil, fmt.Errorf("vfs/localfs: create root: %w", err)
	}
	checker, err := policy.NewPathChecker([]policy.PathGrant{{Root: abs, Access: policy.AccessReadWrite}})
	if err != nil {
		return nil, err
	}
	return &Backend{root: abs, checker: checker}, nil
}

// Root returns the absolute backend root.
func (b *Backend) Root() string { return b.root }

func (b *Backend) resolve(rel string, access policy.PathAccess) (string, error) {
	if filepath.IsAbs(rel) {
		return "", os.ErrPermission
	}
	clean := filepath.Clean(filepath.FromSlash(rel))
	if clean == "." {
		clean = ""
	}
	if err := validateVirtualPath(clean); err != nil {
		return "", err
	}
	abs := filepath.Join(b.root, clean)
	if b.checker != nil && !b.checker.Allowed(abs, access) {
		return "", os.ErrPermission
	}
	return abs, nil
}

func validateVirtualPath(rel string) error {
	if strings.IndexByte(rel, 0) >= 0 {
		return os.ErrPermission
	}
	if filepath.VolumeName(rel) != "" {
		return os.ErrPermission
	}
	if runtime.GOOS != "windows" {
		return nil
	}
	for _, part := range strings.FieldsFunc(rel, func(r rune) bool { return r == '/' || r == '\\' }) {
		if part == "" || part == "." {
			continue
		}
		if strings.Contains(part, ":") ||
			strings.HasSuffix(part, ".") ||
			strings.HasSuffix(part, " ") {
			return os.ErrPermission
		}
		base := strings.ToUpper(strings.SplitN(part, ".", 2)[0])
		switch base {
		case "CON", "PRN", "AUX", "NUL",
			"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
			"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9":
			return os.ErrPermission
		}
	}
	return nil
}

func virtualPath(root, abs string) string {
	rel, err := filepath.Rel(root, abs)
	if err != nil {
		return filepath.ToSlash(abs)
	}
	return filepath.ToSlash(rel)
}

// Stat implements vfs.Backend.
func (b *Backend) Stat(_ context.Context, path string) (vfs.Entry, error) {
	abs, err := b.resolve(path, policy.AccessRead)
	if err != nil {
		return vfs.Entry{}, err
	}
	info, err := os.Stat(abs)
	if err != nil {
		return vfs.Entry{}, mapErr(err)
	}
	return entryFor(b.root, abs, info), nil
}

// Read implements vfs.Backend.
func (b *Backend) Read(_ context.Context, path string) ([]byte, error) {
	abs, err := b.resolve(path, policy.AccessRead)
	if err != nil {
		return nil, err
	}
	data, err := os.ReadFile(abs)
	if err != nil {
		return nil, mapErr(err)
	}
	return data, nil
}

// Write implements vfs.Backend.
func (b *Backend) Write(_ context.Context, path string, data []byte) error {
	abs, err := b.resolve(path, policy.AccessReadWrite)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(abs), 0o700); err != nil {
		return err
	}
	return mapErr(os.WriteFile(abs, data, 0o600))
}

// List implements vfs.Backend.
func (b *Backend) List(_ context.Context, path string) ([]vfs.Entry, error) {
	abs, err := b.resolve(path, policy.AccessRead)
	if err != nil {
		return nil, err
	}
	entries, err := os.ReadDir(abs)
	if err != nil {
		return nil, mapErr(err)
	}
	out := make([]vfs.Entry, 0, len(entries))
	for _, e := range entries {
		info, err := e.Info()
		if err != nil {
			return nil, mapErr(err)
		}
		out = append(out, entryFor(b.root, filepath.Join(abs, e.Name()), info))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Path < out[j].Path })
	return out, nil
}

// Delete implements vfs.Backend.
func (b *Backend) Delete(_ context.Context, path string, recursive bool) error {
	abs, err := b.resolve(path, policy.AccessReadWrite)
	if err != nil {
		return err
	}
	if abs == b.root {
		return errors.New("vfs/localfs: refusing to delete the root")
	}
	if recursive {
		return mapErr(os.RemoveAll(abs))
	}
	return mapErr(os.Remove(abs))
}

// Glob implements vfs.Backend.
func (b *Backend) Glob(_ context.Context, pattern string) ([]string, error) {
	re, err := globRegexp(pattern)
	if err != nil {
		return nil, err
	}
	var out []string
	err = filepath.Walk(b.root, func(p string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return nil
		}
		if info.IsDir() {
			return nil
		}
		rel := virtualPath(b.root, p)
		if re.MatchString(rel) {
			out = append(out, rel)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Strings(out)
	return out, nil
}

// Grep implements vfs.Backend.
func (b *Backend) Grep(_ context.Context, pattern, path string) ([]vfs.Match, error) {
	re, err := regexp.Compile(pattern)
	if err != nil {
		return nil, err
	}
	abs, err := b.resolve(path, policy.AccessRead)
	if err != nil {
		return nil, err
	}
	info, err := os.Stat(abs)
	if err != nil {
		return nil, mapErr(err)
	}
	var out []vfs.Match
	add := func(p string) error {
		data, err := os.ReadFile(p)
		if err != nil {
			return nil
		}
		for i, line := range strings.Split(string(data), "\n") {
			if re.MatchString(line) {
				out = append(out, vfs.Match{Path: virtualPath(b.root, p), Line: i + 1, Text: line})
			}
		}
		return nil
	}
	if info.IsDir() {
		err = filepath.Walk(abs, func(p string, fi os.FileInfo, walkErr error) error {
			if walkErr != nil || fi.IsDir() {
				return nil
			}
			return add(p)
		})
	} else {
		err = add(abs)
	}
	if err != nil {
		return nil, err
	}
	return out, nil
}

func entryFor(root, abs string, info os.FileInfo) vfs.Entry {
	return vfs.Entry{
		Path:    virtualPath(root, abs),
		Name:    info.Name(),
		Size:    info.Size(),
		Mode:    info.Mode().String(),
		IsDir:   info.IsDir(),
		ModTime: info.ModTime().UTC(),
	}
}

func mapErr(err error) error {
	if err == nil {
		return nil
	}
	if os.IsNotExist(err) {
		return fmt.Errorf("%w: %v", vfs.ErrNotFound, err)
	}
	return err
}

func globRegexp(pattern string) (*regexp.Regexp, error) {
	p := filepath.ToSlash(pattern)
	var b strings.Builder
	b.WriteString("^")
	for i := 0; i < len(p); i++ {
		switch p[i] {
		case '*':
			if i+1 < len(p) && p[i+1] == '*' {
				b.WriteString(".*")
				i++
			} else {
				b.WriteString("[^/]*")
			}
		case '?':
			b.WriteString("[^/]")
		default:
			b.WriteString(regexp.QuoteMeta(string(p[i])))
		}
	}
	b.WriteString("$")
	return regexp.Compile(b.String())
}
