package plugin

import "testing"

func FuzzParseManifest(f *testing.F) {
	f.Add([]byte(validManifestForFuzz()))
	f.Add([]byte(`{}`))
	f.Add([]byte(`{"schemaVersion":1}`))
	f.Add([]byte(`{"schemaVersion":1,"id":"com.example.x","version":"1.0.0","kind":"tool.provider.v1","entrypoint":{"type":"process","command":"x"},"protocol":"jsonrpc-2","capabilities":[],"isolation":"process"}`))
	f.Fuzz(func(t *testing.T, data []byte) {
		m, err := ParseManifest(data)
		if err != nil {
			return
		}
		_ = m.Limits.ResourceLimits()
		_ = m.ValidateTrust(TrustUnsigned)
	})
}

func validManifestForFuzz() string {
	return `{
	  "schemaVersion": 1,
	  "id": "com.example.fuzz",
	  "version": "1.0.0",
	  "kind": "tool.provider.v1",
	  "entrypoint": { "type": "process", "command": "./bin/fuzz" },
	  "protocol": "jsonrpc-2",
	  "capabilities": ["tool.invoke"],
	  "permissions": { "filesystem": [{ "path": "/workspace", "mode": "read" }] },
	  "limits": { "memoryMB": 64, "cpuMillis": 1000, "timeoutMs": 1000, "maxInflight": 1 },
	  "isolation": "process"
	}`
}
