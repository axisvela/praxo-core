// Package sandbox defines the execution sandbox boundary.
package sandbox

import (
	"context"
	"time"
)

// Spec describes one sandbox invocation.
type Spec struct {
	Image   string            `json:"image,omitempty"`
	WorkDir string            `json:"workDir,omitempty"`
	Timeout time.Duration     `json:"timeout,omitempty"`
	Env     map[string]string `json:"env,omitempty"`
}

// Result is a sandbox execution result.
type Result struct {
	ExitCode int    `json:"exitCode"`
	Stdout   string `json:"stdout"`
	Stderr   string `json:"stderr"`
}

// Sandbox runs a command in an isolated environment.
type Sandbox interface {
	Run(ctx context.Context, spec Spec, command []string) (Result, error)
}
