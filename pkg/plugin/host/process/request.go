package process

// ProtocolVersion is the JSON-Lines wire protocol version spoken between the
// host and a process plugin over the child's stdio.
const ProtocolVersion = 1

// Request is one invocation envelope sent from host to plugin. Payload is
// opaque contract bytes (base64 on the wire); the Token authenticates the
// channel on every request and is provisioned to the child via environment,
// never argv.
type Request struct {
	ID       string `json:"id"`
	Version  int    `json:"version"`
	PluginID string `json:"plugin_id"`
	Service  string `json:"service"`
	Method   string `json:"method"`
	Token    string `json:"token"`
	Payload  []byte `json:"payload,omitempty"`
}
