//go:build !windows

package process

import "os/exec"

// defaultKill force-kills the main plugin process. POSIX platforms that set a
// process group additionally signal the whole group so descendants do not
// survive.
func defaultKill(cmd *exec.Cmd) {
	if cmd != nil && cmd.Process != nil {
		_ = cmd.Process.Kill()
	}
}
