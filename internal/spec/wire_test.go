package spec

import (
	"encoding/json"
	"path/filepath"
	"strings"
	"testing"
)

func TestWireReferences(t *testing.T) {
	root := repoRoot(t)
	version := strings.TrimSpace(string(readFile(t, filepath.Join(root, vectorDir, "SPEC_VERSION"))))

	var events struct {
		SpecVersion string `json:"specVersion"`
		EventTypes  []struct {
			Type string `json:"type"`
		} `json:"eventTypes"`
		StreamKinds []struct {
			Kind string `json:"kind"`
		} `json:"streamKinds"`
	}
	readJSONFile(t, filepath.Join(root, vectorDir, "wire", "events.json"), &events)

	var errs struct {
		SpecVersion string `json:"specVersion"`
		Sentinels   []struct {
			Code string `json:"code"`
		} `json:"sentinels"`
		PluginCallErrorCodes []string `json:"pluginCallErrorCodes"`
	}
	readJSONFile(t, filepath.Join(root, vectorDir, "wire", "errors.json"), &errs)

	if events.SpecVersion != version {
		t.Errorf("events.json specVersion %q, want %q", events.SpecVersion, version)
	}
	if errs.SpecVersion != version {
		t.Errorf("errors.json specVersion %q, want %q", errs.SpecVersion, version)
	}

	eventTypes := map[string]bool{}
	for _, e := range events.EventTypes {
		eventTypes[e.Type] = true
	}
	streamKinds := map[string]bool{}
	for _, k := range events.StreamKinds {
		streamKinds[k.Kind] = true
	}
	codes := map[string]bool{}
	for _, s := range errs.Sentinels {
		codes[s.Code] = true
	}
	for _, c := range errs.PluginCallErrorCodes {
		codes[c] = true
	}

	for _, f := range loadVectorFiles(t, root) {
		for _, v := range f.Vectors {
			var input, expect map[string]any
			if err := json.Unmarshal(v.Input, &input); err != nil {
				t.Errorf("%s: input: %v", v.ID, err)
				continue
			}
			if err := json.Unmarshal(v.Expect, &expect); err != nil {
				t.Errorf("%s: expect: %v", v.ID, err)
				continue
			}
			checkWireRefs(t, v.ID, input, eventTypes, streamKinds, codes)
			checkWireRefs(t, v.ID, expect, eventTypes, streamKinds, codes)
		}
	}
}

func checkWireRefs(t *testing.T, id string, m map[string]any, events, kinds, codes map[string]bool) {
	t.Helper()
	for key, value := range m {
		switch key {
		case "errorCode":
			s, ok := value.(string)
			if !ok {
				t.Errorf("%s: errorCode is not a string", id)
				continue
			}
			if !codes[s] {
				t.Errorf("%s: unknown error code %q", id, s)
			}
		case "events", "delivered", "predicateTypes":
			for _, item := range stringSlice(value) {
				if !events[item] {
					t.Errorf("%s: unknown event type %q", id, item)
				}
			}
		case "kinds":
			for _, item := range stringSlice(value) {
				if !kinds[item] {
					t.Errorf("%s: unknown stream kind %q", id, item)
				}
			}
		case "perSink":
			if list, ok := value.([]any); ok {
				for _, inner := range list {
					for _, item := range stringSlice(inner) {
						if !events[item] {
							t.Errorf("%s: unknown event type %q", id, item)
						}
					}
				}
			}
		}
	}
}

func stringSlice(v any) []string {
	list, ok := v.([]any)
	if !ok {
		return nil
	}
	out := make([]string, 0, len(list))
	for _, item := range list {
		if s, ok := item.(string); ok {
			out = append(out, s)
		}
	}
	return out
}
