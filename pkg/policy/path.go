package policy

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
)

// PathAccess is a filesystem access level.
type PathAccess string

const (
	// AccessRead permits reading.
	AccessRead PathAccess = "read"
	// AccessWrite permits writing.
	AccessWrite PathAccess = "write"
	// AccessReadWrite permits reading and writing.
	AccessReadWrite PathAccess = "readwrite"
)

// PathGrant grants one filesystem subtree an access level. Roots are resolved
// at construction, so a symlinked root is compared by its real path.
type PathGrant struct {
	Root   string     `json:"root"`
	Access PathAccess `json:"access"`
}

// PathChecker is a deny-by-default filesystem containment check. It resolves
// symlinks on the target and on every grant root before comparing, so a
// symlink cannot move a path outside an allowed root.
type PathChecker struct {
	grants []PathGrant
}

// NewPathChecker resolves the grant roots and returns a checker. An empty
// grant set denies every path.
func NewPathChecker(grants []PathGrant) (*PathChecker, error) {
	out := make([]PathGrant, 0, len(grants))
	for _, g := range grants {
		if g.Root == "" {
			return nil, errors.New("policy: path grant root is required")
		}
		if !validPathAccess(g.Access) {
			return nil, fmt.Errorf("policy: invalid grant access %q", g.Access)
		}
		root, err := resolvePath(g.Root)
		if err != nil {
			return nil, err
		}
		out = append(out, PathGrant{Root: root, Access: g.Access})
	}
	return &PathChecker{grants: out}, nil
}

// Check reports whether target may be used at the requested access level.
// A denial is not an error: callers should inspect Decision.Allowed. An error
// means the path could not be resolved safely (fail closed).
func (c *PathChecker) Check(target string, need PathAccess) (Decision, error) {
	if !validPathAccess(need) {
		return Decision{}, fmt.Errorf("policy: invalid requested access %q", need)
	}
	if c == nil || len(c.grants) == 0 {
		return Decision{Allowed: false, Reason: "no allowed roots"}, nil
	}
	resolved, err := resolvePath(target)
	if err != nil {
		return Decision{}, err
	}
	matched := ""
	for _, g := range c.grants {
		if !within(g.Root, resolved) {
			continue
		}
		matched = g.Root
		if g.Access.allows(need) {
			return Decision{Allowed: true, Reason: "path within " + g.Root}, nil
		}
	}
	if matched != "" {
		return Decision{Allowed: false, Reason: "path within " + matched + " but the grant is insufficient"}, nil
	}
	return Decision{Allowed: false, Reason: "path outside allowed roots"}, nil
}

// Allowed reports whether target may be used at the requested access level.
func (c *PathChecker) Allowed(target string, need PathAccess) bool {
	d, err := c.Check(target, need)
	return err == nil && d.Allowed
}

func validPathAccess(a PathAccess) bool {
	switch a {
	case AccessRead, AccessWrite, AccessReadWrite:
		return true
	default:
		return false
	}
}

func (a PathAccess) allows(need PathAccess) bool {
	switch need {
	case AccessRead:
		return a == AccessRead || a == AccessReadWrite
	case AccessWrite:
		return a == AccessWrite || a == AccessReadWrite
	case AccessReadWrite:
		return a == AccessReadWrite
	default:
		return false
	}
}

func within(root, target string) bool {
	if runtime.GOOS == "windows" {
		root = strings.ToLower(root)
		target = strings.ToLower(target)
	}
	rel, err := filepath.Rel(root, target)
	if err != nil {
		return false
	}
	return rel == "." || (rel != ".." && !strings.HasPrefix(rel, ".."+string(filepath.Separator)))
}

// resolvePath makes p absolute, then resolves symlinks on the path or, when
// the target does not exist yet, on its nearest existing ancestor. A resolution
// failure other than not-exist is returned so callers fail closed.
func resolvePath(p string) (string, error) {
	abs, err := filepath.Abs(p)
	if err != nil {
		return "", fmt.Errorf("policy: resolve %s: %w", p, err)
	}
	abs = filepath.Clean(abs)
	if resolved, err := filepath.EvalSymlinks(abs); err == nil {
		return filepath.Clean(resolved), nil
	} else if !os.IsNotExist(err) {
		return "", fmt.Errorf("policy: resolve %s: %w", p, err)
	}
	tail := ""
	cur := abs
	for {
		parent := filepath.Dir(cur)
		if parent == cur {
			return abs, nil
		}
		tail = filepath.Join(filepath.Base(cur), tail)
		cur = parent
		resolved, err := filepath.EvalSymlinks(cur)
		if err == nil {
			return filepath.Clean(filepath.Join(resolved, tail)), nil
		}
		if !os.IsNotExist(err) {
			return "", fmt.Errorf("policy: resolve %s: %w", cur, err)
		}
	}
}
