package plugin

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"path"
	"path/filepath"
	"regexp"
	"strings"
)

// Manifest is the v1 runtime plugin manifest. Parsing is strict: unknown
// fields and trailing data are rejected.
type Manifest struct {
	SchemaVersion int         `json:"schemaVersion"`
	ID            string      `json:"id"`
	Version       string      `json:"version"`
	Kind          Kind        `json:"kind"`
	Entrypoint    Entrypoint  `json:"entrypoint"`
	Protocol      string      `json:"protocol"`
	Capabilities  []string    `json:"capabilities"`
	Permissions   Permissions `json:"permissions"`
	Limits        Limits      `json:"limits"`
	Isolation     string      `json:"isolation"`
	Health        Health      `json:"health"`
	Signature     *Signature  `json:"signature,omitempty"`
	SBOM          string      `json:"sbom,omitempty"`
}

// Entrypoint describes how the host launches a plugin.
type Entrypoint struct {
	Type    string   `json:"type"`
	Command string   `json:"command,omitempty"`
	Module  string   `json:"module,omitempty"`
	Image   string   `json:"image,omitempty"`
	Args    []string `json:"args,omitempty"`
	Dir     string   `json:"dir,omitempty"`
}

// Permissions is the deny-by-default grant set a manifest declares.
type Permissions struct {
	Filesystem []FilesystemPermission `json:"filesystem,omitempty"`
	Network    []NetworkPermission    `json:"network,omitempty"`
	Env        []string               `json:"env,omitempty"`
}

// FilesystemPermission grants access to one path. Mode is read, write, or
// readwrite.
type FilesystemPermission struct {
	Path string `json:"path"`
	Mode string `json:"mode"`
}

// NetworkPermission grants egress to one host and port.
type NetworkPermission struct {
	Host string `json:"host"`
	Port int    `json:"port"`
}

// Limits bounds one plugin instance.
type Limits struct {
	MemoryMB    int `json:"memoryMB,omitempty"`
	CPUMillis   int `json:"cpuMillis,omitempty"`
	TimeoutMs   int `json:"timeoutMs,omitempty"`
	MaxInflight int `json:"maxInflight,omitempty"`
}

// Health configures the host-side liveness probe.
type Health struct {
	Method     string `json:"method,omitempty"`
	IntervalMs int    `json:"intervalMs,omitempty"`
}

// Signature is the descriptor-signature identity a signed manifest declares.
type Signature struct {
	Algorithm string `json:"algorithm"`
	KeyID     string `json:"keyId"`
}

// TrustProfile selects whether a manifest must carry a signature and SBOM.
type TrustProfile string

const (
	// TrustSigned requires a signature and SBOM (third-party default).
	TrustSigned TrustProfile = "signed"
	// TrustUnsigned is the explicit local-development opt-out.
	TrustUnsigned TrustProfile = "unsigned"
)

var (
	reverseDNS = regexp.MustCompile(`^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$`)
	semver     = regexp.MustCompile(`^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$`)
	envName    = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)
)

// ParseManifest strictly decodes and validates a v1 manifest.
func ParseManifest(data []byte) (Manifest, error) {
	if len(bytes.TrimSpace(data)) == 0 {
		return Manifest{}, errors.New("plugin: manifest is empty")
	}
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	var m Manifest
	if err := dec.Decode(&m); err != nil {
		return Manifest{}, fmt.Errorf("plugin: manifest: %w", err)
	}
	var extra any
	if err := dec.Decode(&extra); err != io.EOF {
		return Manifest{}, errors.New("plugin: manifest: trailing data")
	}
	if err := m.Validate(); err != nil {
		return Manifest{}, err
	}
	return m, nil
}

// Validate checks the v1 manifest rules.
func (m Manifest) Validate() error {
	if m.SchemaVersion != 1 {
		return fmt.Errorf("plugin: manifest: schemaVersion = %d, want 1", m.SchemaVersion)
	}
	if !reverseDNS.MatchString(m.ID) {
		return fmt.Errorf("plugin: manifest: id %q is not reverse-DNS", m.ID)
	}
	if !semver.MatchString(m.Version) {
		return fmt.Errorf("plugin: manifest: version %q is not semver", m.Version)
	}
	if _, ok := Lookup(m.Kind); !ok {
		return fmt.Errorf("plugin: manifest: kind %q is not a known contract", m.Kind)
	}
	if m.Protocol != "jsonrpc-2" {
		return fmt.Errorf("plugin: manifest: protocol = %q, want jsonrpc-2", m.Protocol)
	}
	if err := m.Entrypoint.validate(); err != nil {
		return err
	}
	if m.Isolation != m.Entrypoint.Type {
		return fmt.Errorf("plugin: manifest: isolation %q does not match entrypoint %q", m.Isolation, m.Entrypoint.Type)
	}
	if err := m.Permissions.validate(); err != nil {
		return err
	}
	if err := m.Limits.validate(); err != nil {
		return err
	}
	if err := m.Health.validate(); err != nil {
		return err
	}
	if m.Signature != nil {
		if m.Signature.Algorithm == "" || m.Signature.KeyID == "" {
			return errors.New("plugin: manifest: signature requires algorithm and keyId")
		}
	}
	if m.SBOM != "" {
		if err := validateRelativePath(m.SBOM); err != nil {
			return fmt.Errorf("plugin: manifest: sbom: %w", err)
		}
	}
	if err := validateCapabilities(m.Capabilities); err != nil {
		return err
	}
	return nil
}

// ValidateTrust enforces the selected trust profile.
func (m Manifest) ValidateTrust(profile TrustProfile) error {
	switch profile {
	case TrustSigned:
		if m.Signature == nil {
			return errors.New("plugin: manifest: signed trust profile requires a signature")
		}
		if m.SBOM == "" {
			return errors.New("plugin: manifest: signed trust profile requires an sbom")
		}
		return nil
	case TrustUnsigned:
		return nil
	default:
		return fmt.Errorf("plugin: manifest: unknown trust profile %q", profile)
	}
}

// ResourceLimits converts manifest limits to the host resource limits.
func (l Limits) ResourceLimits() ResourceLimits {
	cpu := 0
	if l.CPUMillis > 0 {
		cpu = (l.CPUMillis + 999) / 1000
	}
	return ResourceLimits{MemoryMB: l.MemoryMB, CPUSeconds: cpu}
}

func (e Entrypoint) validate() error {
	switch e.Type {
	case "process":
		if e.Command == "" {
			return errors.New("plugin: manifest: process entrypoint requires command")
		}
	case "wasm":
		if e.Module == "" {
			return errors.New("plugin: manifest: wasm entrypoint requires module")
		}
	case "container":
		if e.Image == "" {
			return errors.New("plugin: manifest: container entrypoint requires image")
		}
	default:
		return fmt.Errorf("plugin: manifest: unknown entrypoint type %q", e.Type)
	}
	return nil
}

func (p Permissions) validate() error {
	for _, fs := range p.Filesystem {
		if fs.Path == "" {
			return errors.New("plugin: manifest: filesystem permission requires path")
		}
		switch fs.Mode {
		case "read", "write", "readwrite":
		default:
			return fmt.Errorf("plugin: manifest: filesystem mode %q is not read, write, or readwrite", fs.Mode)
		}
	}
	for _, n := range p.Network {
		if n.Host == "" {
			return errors.New("plugin: manifest: network permission requires host")
		}
		if n.Port < 1 || n.Port > 65535 {
			return fmt.Errorf("plugin: manifest: network port %d is out of range", n.Port)
		}
	}
	for _, name := range p.Env {
		if !envName.MatchString(name) {
			return fmt.Errorf("plugin: manifest: env name %q is invalid", name)
		}
	}
	return nil
}

func (l Limits) validate() error {
	if l.MemoryMB < 0 || l.CPUMillis < 0 || l.TimeoutMs < 0 || l.MaxInflight < 0 {
		return errors.New("plugin: manifest: limits must not be negative")
	}
	return nil
}

func (h Health) validate() error {
	if h.IntervalMs < 0 {
		return errors.New("plugin: manifest: health interval must not be negative")
	}
	if h.IntervalMs > 0 && h.Method == "" {
		return errors.New("plugin: manifest: health interval requires method")
	}
	return nil
}

func validateCapabilities(caps []string) error {
	seen := make(map[string]bool, len(caps))
	for _, cap := range caps {
		if cap == "" {
			return errors.New("plugin: manifest: capability must not be empty")
		}
		if seen[cap] {
			return fmt.Errorf("plugin: manifest: duplicate capability %q", cap)
		}
		seen[cap] = true
	}
	return nil
}

func validateRelativePath(p string) error {
	if p == "" {
		return nil
	}
	q := strings.ReplaceAll(p, "\\", "/")
	if path.IsAbs(q) || filepath.IsAbs(p) {
		return errors.New("path must be relative")
	}
	for _, part := range strings.Split(q, "/") {
		if part == ".." {
			return errors.New("path must not contain '..'")
		}
	}
	return nil
}
