package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/plugin/host/process"
)

func main() {
	if err := serve(os.Stdin, os.Stdout, os.Getenv("PRAXOVELA_PLUGIN_TOKEN")); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func serve(in io.Reader, out io.Writer, token string) error {
	scanner := bufio.NewScanner(in)
	scanner.Buffer(make([]byte, 64*1024), 8<<20)
	encoder := json.NewEncoder(out)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var request process.Request
		if err := json.Unmarshal([]byte(line), &request); err != nil {
			if err := encoder.Encode(process.Response{
				Version: process.ProtocolVersion,
				OK:      false,
				Code:    string(plugin.CodeInvalidRequest),
				Message: "invalid request",
			}); err != nil {
				return err
			}
			continue
		}
		if request.Token != token {
			if err := encoder.Encode(failure(request, plugin.CodeCapabilityDenied, "invalid token")); err != nil {
				return err
			}
			continue
		}
		switch request.Service + "/" + request.Method {
		case process.ControlService + "/" + process.MethodHealth:
			if err := encoder.Encode(success(request, nil)); err != nil {
				return err
			}
		case process.ControlService + "/" + process.MethodCancel:
			if err := encoder.Encode(success(request, nil)); err != nil {
				return err
			}
		case process.ControlService + "/" + process.MethodShutdown:
			if err := encoder.Encode(success(request, nil)); err != nil {
				return err
			}
			return nil
		case plugin.ToolProvider.Service + "/invoke":
			if err := encoder.Encode(success(request, request.Payload)); err != nil {
				return err
			}
		default:
			if err := encoder.Encode(failure(request, plugin.CodeNotFound, "unknown method")); err != nil {
				return err
			}
		}
	}
	return scanner.Err()
}

func success(request process.Request, payload []byte) process.Response {
	return process.Response{
		ID:      request.ID,
		Version: process.ProtocolVersion,
		OK:      true,
		Payload: payload,
	}
}

func failure(request process.Request, code plugin.CallErrorCode, message string) process.Response {
	return process.Response{
		ID:      request.ID,
		Version: process.ProtocolVersion,
		OK:      false,
		Code:    string(code),
		Message: message,
	}
}
