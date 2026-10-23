package main

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
	"github.com/axisvela/praxo-core/v2/pkg/plugin/host/process"
)

func TestHostInvokesPlugin(t *testing.T) {
	name := "echo-plugin"
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	binary := filepath.Join(t.TempDir(), name)
	build := exec.Command("go", "build", "-o", binary, "../echo-plugin")
	build.Env = append(os.Environ(), "GOWORK=off")
	if output, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build plugin: %v\n%s", err, output)
	}

	host, err := process.New(process.Config{
		PluginID:      "com.example.echo",
		Path:          binary,
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

	result, err := host.Invoke(ctx, plugin.ToolProvider.Service, "invoke", []byte(`{"hello":"world"}`))
	if err != nil {
		t.Fatal(err)
	}
	if string(result) != `{"hello":"world"}` {
		t.Fatalf("result = %q", result)
	}
}
