package wasm

import (
	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

// Response is one invocation reply sent from plugin to host over the WASM
// guest's linear memory. OK reports success; on failure Code carries a
// plugin.CallErrorCode string.
type Response struct {
	ID      string `json:"id"`
	Version int    `json:"version"`
	OK      bool   `json:"ok"`
	Code    string `json:"code,omitempty"`
	Message string `json:"message,omitempty"`
	Payload []byte `json:"payload,omitempty"`
}

// callError converts a failed response into the typed pluginrt error, mapping
// unknown codes to CodeInternal.
func (r Response) callError(pluginID, service, method string) *plugin.CallError {
	code := plugin.CallErrorCode(r.Code)
	switch code {
	case plugin.CodeCapabilityDenied,
		plugin.CodeNotActive,
		plugin.CodeNotFound,
		plugin.CodeInvalidRequest,
		plugin.CodeTimeout,
		plugin.CodeInternal:
		// ok
	default:
		code = plugin.CodeInternal
	}
	return plugin.NewCallError(code, pluginID, service, method, r.Message)
}
