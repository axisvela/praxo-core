module github.com/axisvela/praxo-core/adapters/workspace/cubesandbox

go 1.25.0

require (
	github.com/axisvela/praxo-core/adapters/workspace v0.0.0
	github.com/axisvela/praxo-core/v2 v2.4.0
	github.com/tencentcloud/CubeSandbox/sdk/go v0.7.3
)

replace github.com/axisvela/praxo-core/adapters/workspace => ..

replace github.com/axisvela/praxo-core/v2 => ../../..
