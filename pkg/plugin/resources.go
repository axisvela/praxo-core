package plugin

// ResourceLimits bounds one hosted runtime plugin process. A zero field means
// "no limit" for that dimension. Limits are enforced by the host process
// supervisor (a Windows Job Object or POSIX per-process rlimits); when a host
// is configured with RequireLimits, failing to apply them is a start error
// rather than a silent unconstrained run.
//
// This is the durable, structured limits type consumed by resource evidence
// (G2-9) and the production host assembly (G2-10).
type ResourceLimits struct {
	// MemoryMB caps the memory a plugin process may commit, in mebibytes
	// (0 = unlimited). On Windows this is applied as a job/process memory
	// limit; on Linux as RLIMIT_AS.
	MemoryMB int `json:"memory_mb,omitempty"`
	// CPUSeconds caps total CPU time the plugin may consume, in seconds
	// (0 = unlimited). Exceeding the bound terminates the child.
	CPUSeconds int `json:"cpu_seconds,omitempty"`
	// MaxProcesses caps the number of concurrently active processes the
	// plugin may create, including itself (0 = unlimited). Exceeding the
	// bound causes process creation to fail.
	MaxProcesses int `json:"max_processes,omitempty"`
}

// IsZero reports whether no dimension is bounded.
func (l ResourceLimits) IsZero() bool {
	return l.MemoryMB == 0 && l.CPUSeconds == 0 && l.MaxProcesses == 0
}

// ResourceUsage reports observed consumption of a hosted plugin process,
// captured at termination for resource evidence. Zero fields mean the
// platform did not report that dimension.
type ResourceUsage struct {
	// PeakMemoryMB is the peak committed memory observed, in mebibytes.
	PeakMemoryMB int `json:"peak_memory_mb,omitempty"`
	// CPUSecondsUsed is the total user+system CPU time consumed, in seconds.
	CPUSecondsUsed float64 `json:"cpu_seconds_used,omitempty"`
	// ActiveProcesses is the number of processes observed in the plugin's
	// containment unit at the time of capture.
	ActiveProcesses int `json:"active_processes,omitempty"`
}
