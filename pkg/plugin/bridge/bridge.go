// Package bridge adapts a runtime plugin host to the framework's provider
// seams. It owns no lifecycle, trust, or policy decisions.
package bridge

import (
	"context"
	"encoding/json"
	"time"

	"github.com/axisvela/praxo-core/pkg/plugin"
)

// Invoker is the narrow host invoke surface the bridges use.
type Invoker interface {
	Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error)
}

// HostInvoker adapts plugin.Host and supplies the instance identity.
type HostInvoker struct {
	Host     plugin.Host
	PluginID string
}

// Invoke implements Invoker.
func (h HostInvoker) Invoke(ctx context.Context, service, method string, payload []byte) ([]byte, error) {
	return h.Host.Invoke(ctx, h.PluginID, service, method, payload)
}

// Codec encodes and decodes the bridge payloads.
type Codec interface {
	Encode(any) ([]byte, error)
	Decode([]byte, any) error
}

// JSONCodec is the default Codec.
type JSONCodec struct{}

// Encode implements Codec.
func (JSONCodec) Encode(v any) ([]byte, error) { return json.Marshal(v) }

// Decode implements Codec.
func (JSONCodec) Decode(data []byte, v any) error { return json.Unmarshal(data, v) }

type config struct {
	method          string
	timeout         time.Duration
	codec           Codec
	pluginID        string
	toolName        string
	toolDescription string
	provider        plugin.ProviderIdentity
}

// Option configures a bridge adapter.
type Option func(*config)

// WithMethod overrides the contract method name.
func WithMethod(method string) Option {
	return func(c *config) {
		if method != "" {
			c.method = method
		}
	}
}

// WithTimeout bounds each bridge call. Zero leaves the host timeout in charge.
func WithTimeout(d time.Duration) Option {
	return func(c *config) { c.timeout = d }
}

// WithCodec replaces the default JSON codec.
func WithCodec(codec Codec) Option {
	return func(c *config) {
		if codec != nil {
			c.codec = codec
		}
	}
}

// WithPluginID sets the plugin identity carried on bridge errors.
func WithPluginID(id string) Option {
	return func(c *config) { c.pluginID = id }
}

// WithToolIdentity sets the tool name and description.
func WithToolIdentity(name, description string) Option {
	return func(c *config) {
		c.toolName = name
		c.toolDescription = description
	}
}

// WithProvider overrides the default provider identity.
func WithProvider(p plugin.ProviderIdentity) Option {
	return func(c *config) { c.provider = p }
}

func newConfig(contract plugin.Contract, opts ...Option) config {
	c := config{
		method: defaultMethod(contract.Kind),
		codec:  JSONCodec{},
		provider: plugin.ProviderIdentity{
			ID:      contract.Service,
			Kind:    string(contract.Kind),
			Version: contract.Version,
		},
	}
	for _, opt := range opts {
		if opt != nil {
			opt(&c)
		}
	}
	if c.method == "" {
		c.method = defaultMethod(contract.Kind)
	}
	if c.codec == nil {
		c.codec = JSONCodec{}
	}
	return c
}

func defaultMethod(kind plugin.Kind) string {
	switch kind {
	case plugin.KindToolProvider:
		return "invoke"
	case plugin.KindModelProvider:
		return "generate"
	case plugin.KindPolicyProvider:
		return "evaluate"
	case plugin.KindMemoryProvider:
		return "access"
	case plugin.KindSandboxProvider:
		return "execute"
	default:
		return "invoke"
	}
}

type caller struct {
	inv      Invoker
	contract plugin.Contract
	cfg      config
}

func newCaller(inv Invoker, contract plugin.Contract, opts ...Option) caller {
	return caller{inv: inv, contract: contract, cfg: newConfig(contract, opts...)}
}

func (c caller) call(ctx context.Context, payload []byte) ([]byte, error) {
	if c.inv == nil {
		return nil, plugin.NewCallError(plugin.CodeInternal, c.cfg.pluginID, c.contract.Service, c.cfg.method, "nil invoker")
	}
	if c.cfg.timeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, c.cfg.timeout)
		defer cancel()
	}
	return c.inv.Invoke(ctx, c.contract.Service, c.cfg.method, payload)
}

func (c caller) invokeRaw(ctx context.Context, in any) ([]byte, error) {
	payload, err := c.cfg.codec.Encode(in)
	if err != nil {
		return nil, plugin.NewCallError(plugin.CodeInvalidRequest, c.cfg.pluginID, c.contract.Service, c.cfg.method, err.Error())
	}
	return c.call(ctx, payload)
}

func (c caller) request(ctx context.Context, in any, out any) error {
	raw, err := c.invokeRaw(ctx, in)
	if err != nil {
		return err
	}
	if out == nil || len(raw) == 0 {
		return nil
	}
	if err := c.cfg.codec.Decode(raw, out); err != nil {
		return plugin.NewCallError(plugin.CodeInternal, c.cfg.pluginID, c.contract.Service, c.cfg.method, err.Error())
	}
	return nil
}
