package main

import (
	"context"
	"os"
	"testing"
	"time"

	wasmhost "github.com/axisvela/praxo-core/v2/pkg/plugin/host/wasm"
)

func TestWASMHostHealthy(t *testing.T) {
	data, err := os.ReadFile("echo.wasm")
	if err != nil {
		t.Fatal(err)
	}
	host, err := wasmhost.New(wasmhost.Config{
		PluginID:      "com.example.echo-wasm",
		ModuleBinary:  data,
		StartTimeout:  10 * time.Second,
		InvokeTimeout: 10 * time.Second,
	})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	if err := host.Start(ctx); err != nil {
		t.Fatal(err)
	}
	defer func() {
		_ = host.Stop(context.Background())
	}()
	if err := host.Healthy(ctx); err != nil {
		t.Fatal(err)
	}
}
