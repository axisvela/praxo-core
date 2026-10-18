package plugin

import (
	"strings"
	"testing"
)

const validProcessManifest = `{
  "schemaVersion": 1,
  "id": "com.example.search",
  "version": "1.2.0",
  "kind": "tool.provider.v1",
  "entrypoint": { "type": "process", "command": "./bin/search" },
  "protocol": "jsonrpc-2",
  "capabilities": ["tool.invoke", "network.egress"],
  "permissions": {
    "filesystem": [{ "path": "/workspace", "mode": "read" }],
    "network": [{ "host": "api.example.com", "port": 443 }],
    "env": ["SEARCH_API_KEY"]
  },
  "limits": { "memoryMB": 256, "cpuMillis": 2000, "timeoutMs": 30000, "maxInflight": 8 },
  "isolation": "process",
  "health": { "method": "health", "intervalMs": 15000 },
  "signature": { "algorithm": "ed25519", "keyId": "axisvela-release-1" },
  "sbom": "sbom.spdx.json"
}`

func TestParseManifestValid(t *testing.T) {
	m, err := ParseManifest([]byte(validProcessManifest))
	if err != nil {
		t.Fatalf("ParseManifest: %v", err)
	}
	if m.ID != "com.example.search" || m.Kind != KindToolProvider {
		t.Fatalf("manifest = %+v", m)
	}
	if m.Limits.ResourceLimits().MemoryMB != 256 || m.Limits.ResourceLimits().CPUSeconds != 2 {
		t.Fatalf("limits = %+v", m.Limits.ResourceLimits())
	}
	if err := m.ValidateTrust(TrustSigned); err != nil {
		t.Fatalf("ValidateTrust(signed): %v", err)
	}
}

func TestParseManifestWasm(t *testing.T) {
	raw := `{
	  "schemaVersion": 1,
	  "id": "com.example.wasm",
	  "version": "0.1.0",
	  "kind": "model.provider.v1",
	  "entrypoint": { "type": "wasm", "module": "plugin.wasm" },
	  "protocol": "jsonrpc-2",
	  "capabilities": ["model.generate"],
	  "isolation": "wasm"
	}`
	m, err := ParseManifest([]byte(raw))
	if err != nil {
		t.Fatal(err)
	}
	if m.Entrypoint.Type != "wasm" || m.Entrypoint.Module != "plugin.wasm" {
		t.Fatalf("entrypoint = %+v", m.Entrypoint)
	}
	if err := m.ValidateTrust(TrustUnsigned); err != nil {
		t.Fatalf("unsigned local dev manifest: %v", err)
	}
}

func TestParseManifestRejectsUnknownField(t *testing.T) {
	raw := strings.Replace(validProcessManifest, `"schemaVersion": 1,`, `"schemaVersion": 1, "unexpected": true,`, 1)
	if _, err := ParseManifest([]byte(raw)); err == nil {
		t.Fatal("unknown field accepted")
	}
}

func TestParseManifestRejectsTrailingData(t *testing.T) {
	if _, err := ParseManifest([]byte(validProcessManifest + "{}")); err == nil {
		t.Fatal("trailing data accepted")
	}
}

func TestManifestValidationTable(t *testing.T) {
	cases := []struct {
		name   string
		mutate func(*Manifest)
	}{
		{"schema", func(m *Manifest) { m.SchemaVersion = 2 }},
		{"id", func(m *Manifest) { m.ID = "example" }},
		{"id-upper", func(m *Manifest) { m.ID = "Com.example" }},
		{"version", func(m *Manifest) { m.Version = "1.2" }},
		{"kind", func(m *Manifest) { m.Kind = "unknown.provider.v1" }},
		{"protocol", func(m *Manifest) { m.Protocol = "grpc" }},
		{"entrypoint-type", func(m *Manifest) { m.Entrypoint.Type = "docker" }},
		{"entrypoint-command", func(m *Manifest) { m.Entrypoint.Command = "" }},
		{"isolation-mismatch", func(m *Manifest) { m.Isolation = "wasm" }},
		{"capability-empty", func(m *Manifest) { m.Capabilities = []string{""} }},
		{"capability-dup", func(m *Manifest) { m.Capabilities = []string{"tool.invoke", "tool.invoke"} }},
		{"fs-mode", func(m *Manifest) { m.Permissions.Filesystem[0].Mode = "execute" }},
		{"fs-path", func(m *Manifest) { m.Permissions.Filesystem[0].Path = "" }},
		{"net-port", func(m *Manifest) { m.Permissions.Network[0].Port = 0 }},
		{"env", func(m *Manifest) { m.Permissions.Env = []string{"1BAD"} }},
		{"limits", func(m *Manifest) { m.Limits.MemoryMB = -1 }},
		{"signature", func(m *Manifest) { m.Signature = &Signature{Algorithm: "", KeyID: ""} }},
		{"sbom-absolute", func(m *Manifest) { m.SBOM = "/etc/passwd" }},
		{"sbom-traversal", func(m *Manifest) { m.SBOM = "../sbom.json" }},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			m, err := ParseManifest([]byte(validProcessManifest))
			if err != nil {
				t.Fatal(err)
			}
			tc.mutate(&m)
			if err := m.Validate(); err == nil {
				t.Fatalf("Validate accepted %s", tc.name)
			}
		})
	}
}

func TestManifestValidateTrust(t *testing.T) {
	m, err := ParseManifest([]byte(strings.Replace(validProcessManifest, `"signature": { "algorithm": "ed25519", "keyId": "axisvela-release-1" },`, `"signature": null,`, 1)))
	if err != nil {
		t.Fatal(err)
	}
	m.SBOM = ""
	if err := m.ValidateTrust(TrustSigned); err == nil {
		t.Fatal("signed profile accepted an unsigned manifest")
	}
	if err := m.ValidateTrust(TrustUnsigned); err != nil {
		t.Fatalf("unsigned profile rejected an unsigned manifest: %v", err)
	}
	if err := m.ValidateTrust(TrustProfile("other")); err == nil {
		t.Fatal("unknown trust profile accepted")
	}
}
