//go:build !windows && !linux

package process

import (
	"os/exec"

	"github.com/axisvela/praxo-core/pkg/plugin"
)

// LimitsAvailable reports that required resource limits cannot be enforced on
// this platform, so a production startup gate must fail closed.
func LimitsAvailable() error { return ErrLimitsUnsupported }

// assignLimits fails closed on platforms without a resource-limit supervisor.
// Whatever limits are requested (even none), there is no containment to
// install, so a RequireLimits host refuses to start rather than running with
// no supervisor at all.
func assignLimits(pid int, limits plugin.ResourceLimits) (resourceHandle, error) {
	return nil, ErrLimitsUnsupported
}

// configureProcess has no process-group or suspend mechanism here.
func configureProcess(cmd *exec.Cmd, suspend bool) {}

// resumeProcess is a no-op: children are never started suspended here.
func resumeProcess(pid int) error { return nil }

// killProcessTree kills the direct plugin process; descendants are not
// contained on this platform.
func killProcessTree(handle resourceHandle, cmd *exec.Cmd) { defaultKill(cmd) }
