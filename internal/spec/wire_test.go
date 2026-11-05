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

func TestWireDescriptions(t *testing.T) {
	root := repoRoot(t)
	version := strings.TrimSpace(string(readFile(t, filepath.Join(root, vectorDir, "SPEC_VERSION"))))

	load := func(name string) map[string]any {
		var doc map[string]any
		readJSONFile(t, filepath.Join(root, vectorDir, "wire", name), &doc)
		if doc["specVersion"] != version {
			t.Errorf("%s specVersion %v, want %s", name, doc["specVersion"], version)
		}
		return doc
	}

	tools := load("tools.json")
	if tools["kind"] != "tools" {
		t.Errorf("tools.json kind %v", tools["kind"])
	}
	requireWireFields(t, "tools.json", tools, "toolSpec", "name", "description", "parameters", "risk")
	requireWireFields(t, "tools.json", tools, "gatewayInfo", "name", "description", "risk")
	requireWireFields(t, "tools.json", tools, "parsedToolCall", "call_id", "name", "operation", "resource", "risk", "reason", "idempotency_key", "input")
	if !wireFlag(t, "tools.json", tools, "toolSpec") {
		t.Error("toolSpec must be wire")
	}
	for _, section := range []string{"gatewayInfo", "parsedToolCall"} {
		if wireFlag(t, "tools.json", tools, section) {
			t.Errorf("%s must not be frozen cross-language wire", section)
		}
	}

	model := load("model.json")
	if model["kind"] != "model" {
		t.Errorf("model.json kind %v", model["kind"])
	}
	requireWireFields(t, "model.json", model, "contentBlock", "type", "text", "image_url", "data")
	requireWireFields(t, "model.json", model, "toolCall", "id", "name", "arguments")
	requireWireFields(t, "model.json", model, "message", "role", "content", "contentBlocks", "toolCalls", "toolId")
	requireWireFields(t, "model.json", model, "request", "model", "messages", "tools", "toolChoice", "responseFormat", "cacheHint", "temperature")
	requireWireFields(t, "model.json", model, "usage", "inputTokens", "outputTokens", "cachedTokens")
	if wireFlag(t, "model.json", model, "streamEvent") {
		t.Error("streamEvent must not be frozen cross-language wire")
	}

	checkpoint := load("checkpoint.json")
	if checkpoint["kind"] != "checkpoint" {
		t.Errorf("checkpoint.json kind %v", checkpoint["kind"])
	}
	requireWireFields(t, "checkpoint.json", checkpoint, "allowlistEnvelope", "type", "data")
	projection := requireWireFields(t, "checkpoint.json", checkpoint, "projection", "id", "session_id", "run_id", "created_at", "effect_cursor")
	if projection["sessionId"] {
		t.Error("checkpoint projection must keep snake_case session_id")
	}
	if !wireFlag(t, "checkpoint.json", checkpoint, "allowlistEnvelope") {
		t.Error("checkpoint allowlistEnvelope must be wire")
	}
	if wireFlag(t, "checkpoint.json", checkpoint, "projection") {
		t.Error("checkpoint projection must not be frozen cross-language wire")
	}
}

func requireWireFields(t *testing.T, file string, doc map[string]any, section string, want ...string) map[string]bool {
	t.Helper()
	value, ok := doc[section].(map[string]any)
	if !ok {
		t.Fatalf("%s: missing object %s", file, section)
	}
	fields, ok := value["fields"].([]any)
	if !ok {
		t.Fatalf("%s: missing fields for %s", file, section)
	}
	names := map[string]bool{}
	for _, field := range fields {
		entry, ok := field.(map[string]any)
		if !ok {
			t.Fatalf("%s: invalid field in %s", file, section)
		}
		name, ok := entry["name"].(string)
		if !ok {
			t.Fatalf("%s: unnamed field in %s", file, section)
		}
		names[name] = true
	}
	for _, name := range want {
		if !names[name] {
			t.Errorf("%s: %s missing field %s", file, section, name)
		}
	}
	return names
}

func wireFlag(t *testing.T, file string, doc map[string]any, section string) bool {
	t.Helper()
	value, ok := doc[section].(map[string]any)
	if !ok {
		t.Fatalf("%s: missing object %s", file, section)
	}
	flag, ok := value["wire"].(bool)
	if !ok {
		t.Fatalf("%s: %s missing wire boolean", file, section)
	}
	return flag
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
