package bridge

import (
	"errors"
	"reflect"
	"testing"
)

func TestVersion(t *testing.T) {
	result, err := Run([]string{"version"}, []byte(`{}`))
	if err != nil {
		t.Fatal(err)
	}
	want := map[string]any{
		"sdkVersion":  SDKVersion,
		"specVersion": SpecVersion,
	}
	if !reflect.DeepEqual(result, want) {
		t.Fatalf("got %#v want %#v", result, want)
	}
}

func TestToolcallParse(t *testing.T) {
	result, err := Run(
		[]string{"toolcall", "parse"},
		[]byte(`{"content":"{\"name\":\"echo\",\"input\":{\"text\":\"hi\"}}"}`),
	)
	if err != nil {
		t.Fatal(err)
	}
	call := result.(map[string]any)["call"].(map[string]any)
	if call["name"] != "echo" {
		t.Fatalf("name: %#v", call["name"])
	}
	input := call["input"].(map[string]any)
	if input["text"] != "hi" {
		t.Fatalf("input: %#v", input)
	}
}

func TestToolcallStrip(t *testing.T) {
	result, err := Run(
		[]string{"toolcall", "strip"},
		[]byte(`{"content":"hello<tool_call name=\"echo\">{}</tool_call>world"}`),
	)
	if err != nil {
		t.Fatal(err)
	}
	if result.(map[string]any)["text"] != "helloworld" {
		t.Fatalf("got %#v", result)
	}
}

func TestJSONSchemaValidate(t *testing.T) {
	result, err := Run(
		[]string{"jsonschema", "validate"},
		[]byte(`{"schema":{"type":"object","required":["name"]},"data":{}}`),
	)
	if err != nil {
		t.Fatal(err)
	}
	if result.(map[string]any)["valid"] != false {
		t.Fatalf("got %#v", result)
	}
	paths := result.(map[string]any)["errorPaths"].([]string)
	if len(paths) != 1 || paths[0] != "$.name" {
		t.Fatalf("paths: %#v", paths)
	}
}

func TestPluginValidate(t *testing.T) {
	manifest := `{"schemaVersion":1,"id":"com.example.echo","version":"1.0.0",` +
		`"kind":"tool.provider.v1","entrypoint":{"type":"process","command":"echo"},` +
		`"protocol":"jsonrpc-2","capabilities":[],"permissions":{},"limits":{},` +
		`"health":{},"isolation":"process"}`
	result, err := Run(
		[]string{"plugin", "validate"},
		[]byte(`{"manifest":`+manifest+`}`),
	)
	if err != nil {
		t.Fatal(err)
	}
	if result.(map[string]any)["valid"] != true {
		t.Fatalf("got %#v", result)
	}
}

func TestUnknownCommand(t *testing.T) {
	_, err := Run([]string{"nope"}, nil)
	var usage *UsageError
	if !errors.As(err, &usage) {
		t.Fatalf("got %v", err)
	}
	if ExitCode(err) != 2 {
		t.Fatalf("exit code: %d", ExitCode(err))
	}
}

func TestInvalidJSON(t *testing.T) {
	_, err := Run([]string{"toolcall", "parse"}, []byte(`{`))
	var contract *ContractError
	if !errors.As(err, &contract) || contract.Code != "BRIDGE_JSON" {
		t.Fatalf("got %v", err)
	}
}
