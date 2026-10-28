package process

import (
	"context"
	"errors"
	"net"
	"os/exec"
	"testing"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/plugin"
)

func TestDieAfterHealth(t *testing.T) {
	listener, err := net.ListenTCP("tcp", &net.TCPAddr{IP: net.IPv4(127, 0, 0, 1)})
	if err != nil {
		t.Fatalf("ListenTCP: %v", err)
	}
	defer listener.Close()

	h := startFake(t, "FAKE_DIE_AFTER_HEALTH="+listener.Addr().String())
	if err := listener.SetDeadline(time.Now().Add(3 * time.Second)); err != nil {
		t.Fatalf("SetDeadline: %v", err)
	}
	conn, err := listener.AcceptTCP()
	if err != nil {
		t.Fatalf("AcceptTCP: %v", err)
	}
	defer conn.Close()

	select {
	case <-h.Exited():
		t.Fatal("plugin exited before the post-Start signal")
	default:
	}
	if err := h.Healthy(context.Background()); err != nil {
		t.Fatalf("Healthy before exit signal: %v", err)
	}
	if err := conn.SetWriteDeadline(time.Now().Add(3 * time.Second)); err != nil {
		t.Fatalf("SetWriteDeadline: %v", err)
	}
	if _, err := conn.Write([]byte{1}); err != nil {
		t.Fatalf("signal plugin exit: %v", err)
	}

	select {
	case <-h.Exited():
	case <-time.After(time.Second):
		t.Fatal("Exited channel not closed after plugin exit")
	}
	var exitErr *exec.ExitError
	if err := h.ExitError(); !errors.As(err, &exitErr) || exitErr.ExitCode() != 3 {
		t.Fatalf("ExitError = %v, want exit code 3", err)
	}
	if err := h.Healthy(context.Background()); err == nil {
		t.Fatal("Healthy after plugin exit succeeded, want error")
	}
	_, err = h.Invoke(context.Background(), "tool.provider", "echo", nil)
	var callErr *plugin.CallError
	if !errors.As(err, &callErr) || callErr.Code() != plugin.CodeNotActive {
		t.Fatalf("post-exit error = %v, want CallError NOT_ACTIVE", err)
	}
}
