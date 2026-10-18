package jsonschema

import "testing"

func FuzzFromJSON(f *testing.F) {
	f.Add([]byte(`{"type":"object","required":["a"],"properties":{"a":{"type":"string"}}}`))
	f.Add([]byte(`{"type":"array","items":{"type":"number"}}`))
	f.Add([]byte(`{}`))
	f.Add([]byte(`null`))
	f.Fuzz(func(t *testing.T, data []byte) {
		s, err := FromJSON(data)
		if err != nil || s == nil {
			return
		}
		_ = s.Validate(map[string]any{"a": "x", "b": float64(1)})
		_ = s.Validate([]any{"x", float64(1)})
	})
}
