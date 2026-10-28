//go:build windows

package process

import (
	"fmt"
	"os/exec"
	"sync"
	"syscall"
	"unsafe"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"golang.org/x/sys/windows"
)

// LimitsAvailable reports whether the platform can enforce required resource
// limits. Windows always has Job Objects, so the required supervisor is
// available; the production startup gate consults this before booting.
func LimitsAvailable() error { return nil }

// jobResourceHandle owns the Job Object that contains one plugin process tree.
// Closing it (or killing the host) terminates every process still in the job.
type jobResourceHandle struct {
	mu  sync.Mutex
	job windows.Handle
}

// Close releases the job handle, which triggers kill-on-close and reaps any
// descendant that escaped the plugin's own exit.
func (h *jobResourceHandle) Close() error {
	if h == nil {
		return nil
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.job == 0 {
		return nil
	}
	job := h.job
	h.job = 0
	return closeJobObject(job)
}

// Usage reports peak memory, CPU time and active processes for the job.
func (h *jobResourceHandle) Usage() (plugin.ResourceUsage, error) {
	if h == nil {
		return plugin.ResourceUsage{}, nil
	}
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.job == 0 {
		return plugin.ResourceUsage{}, nil
	}
	return queryJobUsage(h.job)
}

// assignLimits creates and configures a Job Object and binds pid to it. It
// always installs kill-on-close (even with zero limits) so descendants cannot
// outlive the host, and returns an error if the job cannot be created,
// configured, or assigned.
func assignLimits(pid int, limits plugin.ResourceLimits) (resourceHandle, error) {
	job, err := createJobObject()
	if err != nil {
		return nil, err
	}
	if err := applyJobLimits(job, limits); err != nil {
		_ = closeJobObject(job)
		return nil, err
	}
	if err := assignProcessToJob(job, pid); err != nil {
		_ = closeJobObject(job)
		return nil, err
	}
	return &jobResourceHandle{job: job}, nil
}

// killProcessTree terminates the whole job if a handle is present, falling back
// to killing the main process.
func killProcessTree(handle resourceHandle, cmd *exec.Cmd) {
	if jh, ok := handle.(*jobResourceHandle); ok && jh != nil {
		jh.mu.Lock()
		if jh.job != 0 {
			_ = terminateJob(jh.job)
			jh.mu.Unlock()
			return
		}
		jh.mu.Unlock()
	}
	if cmd != nil && cmd.Process != nil {
		_ = cmd.Process.Kill()
	}
}

// configureProcess starts the child suspended when suspend is set so the host
// can assign it to the Job Object before it executes. Containment is the Job
// Object's responsibility, not a POSIX process group.
func configureProcess(cmd *exec.Cmd, suspend bool) {
	if suspend {
		cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: windows.CREATE_SUSPENDED}
	}
}

// resumeProcess resumes every thread of a process created with
// CREATE_SUSPENDED. The primary thread is the only one at creation, but all
// matching threads are resumed defensively. It enumerates the system thread
// list via Toolhelp32 and resumes threads owned by pid.
func resumeProcess(pid int) error {
	snap, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPTHREAD, 0)
	if err != nil {
		return fmt.Errorf("thread snapshot: %w", err)
	}
	defer windows.CloseHandle(snap)

	entry := windows.ThreadEntry32{Size: uint32(unsafe.Sizeof(windows.ThreadEntry32{}))}
	if err := windows.Thread32First(snap, &entry); err != nil {
		return fmt.Errorf("enumerate threads: %w", err)
	}
	resumed := 0
	for {
		if entry.OwnerProcessID == uint32(pid) {
			th, err := windows.OpenThread(windows.THREAD_SUSPEND_RESUME, false, entry.ThreadID)
			if err == nil {
				if _, rerr := windows.ResumeThread(th); rerr == nil {
					resumed++
				}
				_ = windows.CloseHandle(th)
			}
		}
		if err := windows.Thread32Next(snap, &entry); err != nil {
			break
		}
	}
	if resumed == 0 {
		return fmt.Errorf("no resumable threads found for pid %d", pid)
	}
	return nil
}
