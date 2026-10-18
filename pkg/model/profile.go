package model

// ProviderProfile describes provider/model capabilities that affect harness
// behavior. The framework does not ship vendor defaults; products register
// the profiles they support.
type ProviderProfile struct {
	Name                string
	ModelPrefixes       []string
	ContextWindow       int
	MaxOutputTokens     int
	SupportsTools       bool
	SupportsStreaming   bool
	SupportsPromptCache bool
	// ToolCallFormat is advisory: "native", "text", or a product-defined value.
	ToolCallFormat string
}

// ProfileRegistry resolves a provider profile by model-id prefix.
type ProfileRegistry struct {
	profiles []ProviderProfile
}

// NewProfileRegistry returns a registry over profiles.
func NewProfileRegistry(profiles ...ProviderProfile) *ProfileRegistry {
	return &ProfileRegistry{profiles: append([]ProviderProfile(nil), profiles...)}
}

// Resolve returns the longest matching model prefix. A model without a match
// reports false so the caller can choose a policy.
func (r *ProfileRegistry) Resolve(modelID string) (ProviderProfile, bool) {
	if r == nil {
		return ProviderProfile{}, false
	}
	best := ProviderProfile{}
	bestLen := -1
	for _, p := range r.profiles {
		for _, prefix := range p.ModelPrefixes {
			if prefix == "" || len(prefix) > len(modelID) || modelID[:len(prefix)] != prefix {
				continue
			}
			if len(prefix) > bestLen {
				best, bestLen = p, len(prefix)
			}
		}
	}
	return best, bestLen >= 0
}

// List returns the registered profiles.
func (r *ProfileRegistry) List() []ProviderProfile {
	if r == nil {
		return nil
	}
	return append([]ProviderProfile(nil), r.profiles...)
}
