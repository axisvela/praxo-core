module github.com/axisvela/praxo-core/adapters/a2a

go 1.26.0

require (
	github.com/a2aproject/a2a-go/v2 v2.7.0
	github.com/axisvela/praxo-core/v2 v2.1.0
	google.golang.org/grpc v1.83.2
)

require (
	github.com/google/uuid v1.6.0 // indirect
	golang.org/x/mod v0.38.0 // indirect
	golang.org/x/net v0.58.0 // indirect
	golang.org/x/sync v0.22.0 // indirect
	golang.org/x/sys v0.47.0 // indirect
	golang.org/x/text v0.41.0 // indirect
	google.golang.org/genproto/googleapis/api v0.0.0-20260526163538-3dc84a4a5aaa // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260526163538-3dc84a4a5aaa // indirect
	google.golang.org/protobuf v1.36.11 // indirect
)

replace github.com/axisvela/praxo-core/v2 => ../..
