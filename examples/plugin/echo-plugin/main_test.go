package main

import (
	"bytes"
	"encoding/json"
	"io"
	"testing"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/plugin/host/process"
)

func encodeRequests(t *testing.T, requests ...process.Request) *bytes.Buffer {
	t.Helper()
	var buffer bytes.Buffer
	encoder := json.NewEncoder(&buffer)
	for _, request := range requests {
		if request.Version == 0 {
			request.Version = process.ProtocolVersion
		}
		if err := encoder.Encode(request); err != nil {
			t.Fatal(err)
		}
	}
	return &buffer
}

func decodeResponses(t *testing.T, buffer *bytes.Buffer) []process.Response {
	t.Helper()
	var responses []process.Response
	decoder := json.NewDecoder(buffer)
	for {
		var response process.Response
		if err := decoder.Decode(&response); err != nil {
			if err == io.EOF {
				break
			}
			t.Fatal(err)
		}
		responses = append(responses, response)
	}
	return responses
}

func TestServeHandlesLifecycle(t *testing.T) {
	input := encodeRequests(t,
		process.Request{ID: "1", Service: process.ControlService, Method: process.MethodHealth, Token: "secret"},
		process.Request{ID: "2", Service: plugin.ToolProvider.Service, Method: "invoke", Token: "secret", Payload: []byte("hello")},
		process.Request{ID: "3", Service: process.ControlService, Method: process.MethodShutdown, Token: "secret"},
	)
	var output bytes.Buffer
	if err := serve(input, &output, "secret"); err != nil {
		t.Fatal(err)
	}
	responses := decodeResponses(t, &output)
	if len(responses) != 3 {
		t.Fatalf("responses = %d", len(responses))
	}
	for _, response := range responses {
		if !response.OK {
			t.Fatalf("response = %#v", response)
		}
	}
	if string(responses[1].Payload) != "hello" {
		t.Fatalf("payload = %q", responses[1].Payload)
	}
}

func TestServeRejectsBadToken(t *testing.T) {
	input := encodeRequests(t, process.Request{
		ID: "1", Service: process.ControlService, Method: process.MethodHealth, Token: "wrong",
	})
	var output bytes.Buffer
	if err := serve(input, &output, "secret"); err != nil {
		t.Fatal(err)
	}
	responses := decodeResponses(t, &output)
	if len(responses) != 1 || responses[0].OK || responses[0].Code != string(plugin.CodeCapabilityDenied) {
		t.Fatalf("responses = %#v", responses)
	}
}

func TestServeUnknownMethod(t *testing.T) {
	input := encodeRequests(t, process.Request{
		ID: "1", Service: "unknown", Method: "missing", Token: "secret",
	})
	var output bytes.Buffer
	if err := serve(input, &output, "secret"); err != nil {
		t.Fatal(err)
	}
	responses := decodeResponses(t, &output)
	if len(responses) != 1 || responses[0].OK || responses[0].Code != string(plugin.CodeNotFound) {
		t.Fatalf("responses = %#v", responses)
	}
}
