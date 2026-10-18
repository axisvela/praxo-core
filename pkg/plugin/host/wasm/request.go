package wasm

// ProtocolVersion is the JSON-Lines wire protocol version spoken between the
// host and a WASM plugin over the guest's linear memory.
const ProtocolVersion = 1

// Request is one invocation envelope sent from host to plugin over the WASM
// guest's linear memory. Payload is opaque contract bytes. Token authenticates
// the channel; it is provisioned to the guest at Start and verified on every
// request.
type Request struct {
	ID       string `json:"id"`
	Version  int    `json:"version"`
	PluginID string `json:"plugin_id"`
	Service  string `json:"service"`
	Method   string `json:"method"`
	Token    string `json:"token"`
	Payload  []byte `json:"payload,omitempty"`
}
