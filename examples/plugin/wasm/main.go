package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	wasmhost "github.com/axisvela/praxo-core/v2/pkg/plugin/host/wasm"
)

func main() {
	module := flag.String("module", "./examples/plugin/wasm/echo.wasm", "path to the WASM plugin")
	flag.Parse()

	data, err := os.ReadFile(*module)
	if err != nil {
		log.Fatal(err)
	}
	host, err := wasmhost.New(wasmhost.Config{
		PluginID:      "com.example.echo-wasm",
		ModuleBinary:  data,
		StartTimeout:  10 * time.Second,
		InvokeTimeout: 10 * time.Second,
	})
	if err != nil {
		log.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := host.Start(ctx); err != nil {
		log.Fatal(err)
	}
	defer func() {
		_ = host.Stop(context.Background())
	}()
	if err := host.Healthy(ctx); err != nil {
		log.Fatal(err)
	}
	fmt.Println("wasm plugin healthy")
}
