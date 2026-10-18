//go:build linux

package process

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"syscall"

	"github.com/axisvela/praxo-core/pkg/plugin"
	"golang.org/x/sys/unix"
)

// LimitsAvailable reports whether the platform can enforce required resource
// limits. Linux uses per-process rlimits/cgroups, so the required supervisor is
// available; the production startup gate consults this before booting.
func LimitsAvailable() error { return nil }

// rlimitResourceHandle tracks a plugin process whose per-process rlimits were
// installed after spawn. POSIX rlimits have no handle to release.
type rlimitResourceHandle struct {
	pid int
}

// Close is a no-op: rlimits are owned by the process and disappear with it.
func (h *rlimitResourceHandle) Close() error { return nil }

// Usage reports what /proc exposes while the process is alive. rlimits leave
// no durable accounting object, so terminated processes report zero usage.
func (h *rlimitResourceHandle) Usage() (plugin.ResourceUsage, error) {
	if h == nil || h.pid <= 0 {
		return plugin.ResourceUsage{}, nil
	}
	data, err := os.ReadFile(fmt.Sprintf("/proc/%d/status", h.pid))
	if err != nil {
		return plugin.ResourceUsage{}, nil
	}
	var usage plugin.ResourceUsage
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "VmHWM:") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				if kb, err := strconv.Atoi(fields[1]); err == nil {
					usage.PeakMemoryMB = kb >> 10
				}
			}
		}
	}
	return usage, nil
}

// assignLimits installs per-process rlimits on the already-spawned child using
// prlimit(2). RLIMIT_AS bounds address space, RLIMIT_NPROC bounds process
// creation, and RLIMIT_CPU bounds CPU time; all are inherited by descendants.
// Zero dimensions are left untouched, and any prlimit failure is returned so
// RequireLimits hosts can fail closed.
//
// LIMITATION: RLIMIT_NPROC is counted per real UID across the whole system,
// not per plugin or per process tree. A low value therefore throttles the
// host's own processes too, and it is not enforced at all for uid 0. It is a
// coarse backstop, not a per-containment process-count guarantee.
func assignLimits(pid int, limits plugin.ResourceLimits) (resourceHandle, error) {
	if limits.IsZero() {
		return nil, nil
	}
	if limits.MemoryMB > 0 {
		bytes := uint64(limits.MemoryMB) << 20
		if err := unix.Prlimit(pid, unix.RLIMIT_AS, &unix.Rlimit{Cur: bytes, Max: bytes}, nil); err != nil {
			return nil, fmt.Errorf("set RLIMIT_AS: %w", err)
		}
	}
	if limits.MaxProcesses > 0 {
		n := uint64(limits.MaxProcesses)
		if err := unix.Prlimit(pid, unix.RLIMIT_NPROC, &unix.Rlimit{Cur: n, Max: n}, nil); err != nil {
			return nil, fmt.Errorf("set RLIMIT_NPROC: %w", err)
		}
	}
	if limits.CPUSeconds > 0 {
		n := uint64(limits.CPUSeconds)
		if err := unix.Prlimit(pid, unix.RLIMIT_CPU, &unix.Rlimit{Cur: n, Max: n}, nil); err != nil {
			return nil, fmt.Errorf("set RLIMIT_CPU: %w", err)
		}
	}
	return &rlimitResourceHandle{pid: pid}, nil
}

// configureProcess places the child in its own process group so the host can
// signal the whole tree, not only the direct plugin process. Linux has no
// pre-exec suspend hook here, so suspend is ignored.
func configureProcess(cmd *exec.Cmd, suspend bool) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
}

// resumeProcess is a no-op: Linux children are never started suspended here.
func resumeProcess(pid int) error { return nil }

// killProcessTree kills the child's process group, then the direct process.
//
// LIMITATION: process-group containment is advisory against a hostile child.
// A descendant that calls setsid(2) (or is otherwise reparented into a new
// session/group) leaves this group and is not reached by the group SIGKILL.
// Combined with RLIMIT_NPROC's real, system-wide UID accounting, Linux does
// not provide the hard per-tree containment of a Windows Job Object. Hard
// containment would require cgroup v2 pids/`memory` controllers with a
// delegated cgroup per plugin, which needs cgroupfs write access and is not
// assumed here.
func killProcessTree(handle resourceHandle, cmd *exec.Cmd) {
	if cmd != nil && cmd.Process != nil {
		_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
	}
	defaultKill(cmd)
}
