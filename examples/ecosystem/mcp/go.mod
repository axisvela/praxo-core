module github.com/axisvela/praxo-core/examples/ecosystem/mcp

go 1.25.0

require (
	github.com/axisvela/praxo-core/adapters/mcp v0.3.0
	github.com/modelcontextprotocol/go-sdk v1.8.0
)

require (
	github.com/axisvela/praxo-core/v2 v2.4.0 // indirect
	github.com/google/jsonschema-go v0.4.3 // indirect
	github.com/segmentio/asm v1.1.3 // indirect
	github.com/segmentio/encoding v0.5.4 // indirect
	github.com/yosida95/uritemplate/v3 v3.0.2 // indirect
	golang.org/x/oauth2 v0.35.0 // indirect
	golang.org/x/sync v0.20.0 // indirect
	golang.org/x/sys v0.44.0 // indirect
	golang.org/x/time v0.15.0 // indirect
)

replace github.com/axisvela/praxo-core/adapters/mcp => ../../../adapters/mcp

replace github.com/axisvela/praxo-core/v2 => ../../..
