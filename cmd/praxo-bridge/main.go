package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"

	"github.com/axisvela/praxo-core/v2/internal/bridge"
)

func main() {
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		fail("BRIDGE_IO", err)
	}
	emit := func(value any) {
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetEscapeHTML(false)
		if err := encoder.Encode(value); err != nil {
			fmt.Fprintln(os.Stderr, err)
		}
	}
	result, err := bridge.RunWithEmitter(os.Args[1:], input, emit)
	if err != nil {
		var contract *bridge.ContractError
		if errors.As(err, &contract) {
			fail(contract.Code, err)
		}
		var usage *bridge.UsageError
		if errors.As(err, &usage) {
			fail("BRIDGE_USAGE", err)
		}
		fail("BRIDGE_COMMAND", err)
	}
	if result != nil {
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetEscapeHTML(false)
		if err := encoder.Encode(result); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	}
}

func fail(code string, err error) {
	encoder := json.NewEncoder(os.Stdout)
	encoder.SetEscapeHTML(false)
	_ = encoder.Encode(map[string]any{
		"error": map[string]any{
			"code":    code,
			"message": err.Error(),
		},
	})
	fmt.Fprintln(os.Stderr, err.Error())
	var usage *bridge.UsageError
	if errors.As(err, &usage) {
		os.Exit(2)
	}
	os.Exit(1)
}
