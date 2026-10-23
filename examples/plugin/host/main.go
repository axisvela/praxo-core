package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/plugin/host/process"
)

func main() {
	pluginPath := flag.String("plugin", "./echo-plugin", "path to the echo plugin executable")
	payload := flag.String("payload", `{"hello":"world"}`, "tool invoke payload")
	flag.Parse()

	host, err := process.New(process.Config{
		PluginID:      "com.example.echo",
		Path:          *pluginPath,
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

	result, err := host.Invoke(ctx, plugin.ToolProvider.Service, "invoke", []byte(*payload))
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(string(result))
}
