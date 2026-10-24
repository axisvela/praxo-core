module github.com/axisvela/praxo-core/adapters/workspace/opensandbox

go 1.25.0

require (
	github.com/alibaba/OpenSandbox/sdks/sandbox/go v1.1.1
	github.com/axisvela/praxo-core/adapters/workspace v0.0.0
	github.com/axisvela/praxo-core/v2 v2.4.0
)

require golang.org/x/sync v0.7.0 // indirect

replace github.com/axisvela/praxo-core/adapters/workspace => ..

replace github.com/axisvela/praxo-core/v2 => ../../..
