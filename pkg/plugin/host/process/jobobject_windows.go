//go:build windows

package process

import (
	"fmt"
	"unsafe"

	"github.com/axisvela/praxo-core/pkg/plugin"
	"golang.org/x/sys/windows"
)

// jobObjectBasicAccountingInformation mirrors JOBOBJECT_BASIC_ACCOUNTING_INFORMATION
// (not exposed by x/sys/windows) for usage reporting.
type jobObjectBasicAccountingInformation struct {
	TotalUserTime             int64
	TotalKernelTime           int64
	ThisPeriodTotalUserTime   int64
	ThisPeriodTotalKernelTime int64
	TotalPageFaultCount       uint32
	TotalProcesses            uint32
	ActiveProcesses           uint32
	TotalTerminatedProcesses  uint32
}

// createJobObject creates an anonymous Job Object. The caller owns the handle
// and must close it with closeJobObject.
func createJobObject() (windows.Handle, error) {
	job, err := windows.CreateJobObject(nil, nil)
	if err != nil {
		return 0, fmt.Errorf("create job object: %w", err)
	}
	return job, nil
}

// applyJobLimits configures the job with kill-on-close plus every bounded
// ResourceLimits dimension. Zero dimensions are left unlimited.
func applyJobLimits(job windows.Handle, limits plugin.ResourceLimits) error {
	info := windows.JOBOBJECT_EXTENDED_LIMIT_INFORMATION{}
	// Descendants must never outlive the host: closing the last job handle
	// terminates everything still associated with the job.
	info.BasicLimitInformation.LimitFlags = windows.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE

	if limits.MemoryMB > 0 {
		bytes := uintptr(limits.MemoryMB) << 20
		info.ProcessMemoryLimit = bytes
		info.JobMemoryLimit = bytes
		info.BasicLimitInformation.LimitFlags |=
			windows.JOB_OBJECT_LIMIT_PROCESS_MEMORY | windows.JOB_OBJECT_LIMIT_JOB_MEMORY
	}
	if limits.MaxProcesses > 0 {
		info.BasicLimitInformation.ActiveProcessLimit = uint32(limits.MaxProcesses)
		info.BasicLimitInformation.LimitFlags |= windows.JOB_OBJECT_LIMIT_ACTIVE_PROCESS
	}
	if limits.CPUSeconds > 0 {
		// PerProcessUserTimeLimit / PerJobUserTimeLimit are in 100ns units.
		ticks := int64(limits.CPUSeconds) * 10_000_000
		info.BasicLimitInformation.PerProcessUserTimeLimit = ticks
		info.BasicLimitInformation.PerJobUserTimeLimit = ticks
		info.BasicLimitInformation.LimitFlags |=
			windows.JOB_OBJECT_LIMIT_PROCESS_TIME | windows.JOB_OBJECT_LIMIT_JOB_TIME
	}

	if _, err := windows.SetInformationJobObject(
		job,
		windows.JobObjectExtendedLimitInformation,
		uintptr(unsafe.Pointer(&info)),
		uint32(unsafe.Sizeof(info)),
	); err != nil {
		return fmt.Errorf("set job limits: %w", err)
	}
	return nil
}

// assignProcessToJob binds pid to the job. The process is opened with the
// minimum rights required to assign it (SET_QUOTA + TERMINATE).
func assignProcessToJob(job windows.Handle, pid int) error {
	ph, err := windows.OpenProcess(windows.PROCESS_SET_QUOTA|windows.PROCESS_TERMINATE, false, uint32(pid))
	if err != nil {
		return fmt.Errorf("open process %d: %w", pid, err)
	}
	defer windows.CloseHandle(ph)
	if err := windows.AssignProcessToJobObject(job, ph); err != nil {
		return fmt.Errorf("assign process %d to job: %w", pid, err)
	}
	return nil
}

// queryJobUsage reports peak committed memory, total CPU time and the current
// active process count for the job.
func queryJobUsage(job windows.Handle) (plugin.ResourceUsage, error) {
	var info windows.JOBOBJECT_EXTENDED_LIMIT_INFORMATION
	if err := windows.QueryInformationJobObject(
		job,
		windows.JobObjectExtendedLimitInformation,
		uintptr(unsafe.Pointer(&info)),
		uint32(unsafe.Sizeof(info)),
		nil,
	); err != nil {
		return plugin.ResourceUsage{}, fmt.Errorf("query job limits: %w", err)
	}

	var acct jobObjectBasicAccountingInformation
	_ = windows.QueryInformationJobObject(
		job,
		windows.JobObjectBasicAccountingInformation,
		uintptr(unsafe.Pointer(&acct)),
		uint32(unsafe.Sizeof(acct)),
		nil,
	)

	return plugin.ResourceUsage{
		PeakMemoryMB:    int(info.PeakJobMemoryUsed >> 20),
		CPUSecondsUsed:  float64(acct.TotalUserTime+acct.TotalKernelTime) / 1e7,
		ActiveProcesses: int(acct.ActiveProcesses),
	}, nil
}

// terminateJob force-terminates every process in the job.
func terminateJob(job windows.Handle) error {
	if err := windows.TerminateJobObject(job, 1); err != nil {
		return fmt.Errorf("terminate job: %w", err)
	}
	return nil
}

// closeJobObject closes the job handle. With JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
// set, this terminates any descendants still running.
func closeJobObject(job windows.Handle) error {
	if job == 0 {
		return nil
	}
	if err := windows.CloseHandle(job); err != nil {
		return fmt.Errorf("close job: %w", err)
	}
	return nil
}
