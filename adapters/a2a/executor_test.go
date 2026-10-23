package a2a

import (
	"context"
	"errors"
	"net"
	"net/http/httptest"
	"testing"

	sdk "github.com/a2aproject/a2a-go/v2/a2a"
	"github.com/a2aproject/a2a-go/v2/a2aclient"
	"github.com/a2aproject/a2a-go/v2/a2agrpc/v1"
	"github.com/a2aproject/a2a-go/v2/a2asrv"
	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/test/bufconn"
)

var _ Runner = (*agent.Agent)(nil)

type fakeRunner struct {
	session agent.Session
	prompt  string
	result  *agent.Result
	err     error
}

func (f *fakeRunner) Run(_ context.Context, session agent.Session, prompt string) (*agent.Result, error) {
	f.session = session
	f.prompt = prompt
	return f.result, f.err
}

func TestExecuteMapsMessageAndSession(t *testing.T) {
	runner := &fakeRunner{result: &agent.Result{Output: "agent reply"}}
	executor := Executor{Agent: runner}
	message := sdk.NewMessage(sdk.MessageRoleUser,
		sdk.NewTextPart("hello"),
		sdk.NewTextPart("world"),
	)
	events := executor.Execute(context.Background(), &a2asrv.ExecutorContext{
		Message:   message,
		ContextID: "context-1",
		TaskID:    "task-1",
		Tenant:    "acme",
		Metadata:  map[string]any{"workspaceId": "workspace-1"},
	})
	var emitted []sdk.Event
	for event, err := range events {
		if err != nil {
			t.Fatal(err)
		}
		emitted = append(emitted, event)
	}
	if runner.prompt != "hello\nworld" {
		t.Fatalf("prompt = %q", runner.prompt)
	}
	if runner.session.ID != "context-1" || runner.session.TenantID != "acme" || runner.session.WorkspaceID != "workspace-1" {
		t.Fatalf("session = %#v", runner.session)
	}
	if len(emitted) != 1 {
		t.Fatalf("events = %d", len(emitted))
	}
	reply, ok := emitted[0].(*sdk.Message)
	if !ok || reply.Role != sdk.MessageRoleAgent || len(reply.Parts) != 1 {
		t.Fatalf("event = %#v", emitted[0])
	}
	if text, ok := reply.Parts[0].Content.(sdk.Text); !ok || string(text) != "agent reply" {
		t.Fatalf("reply = %#v", reply)
	}
}

func TestExecuteUsesCustomSession(t *testing.T) {
	runner := &fakeRunner{result: &agent.Result{Output: "ok"}}
	executor := Executor{
		Agent: runner,
		Session: func(*a2asrv.ExecutorContext) agent.Session {
			return agent.Session{ID: "custom", TenantID: "custom-tenant"}
		},
	}
	for _, err := range executor.Execute(context.Background(), &a2asrv.ExecutorContext{
		Message: sdk.NewMessage(sdk.MessageRoleUser, sdk.NewTextPart("hi")),
	}) {
		if err != nil {
			t.Fatal(err)
		}
	}
	if runner.session.ID != "custom" || runner.session.TenantID != "custom-tenant" {
		t.Fatalf("session = %#v", runner.session)
	}
}

func TestExecuteRequiresAgentAndText(t *testing.T) {
	if _, err := collect(Executor{}.Execute(context.Background(), &a2asrv.ExecutorContext{})); !errors.Is(err, ErrAgentRequired) {
		t.Fatalf("got %v, want %v", err, ErrAgentRequired)
	}
	runner := &fakeRunner{result: &agent.Result{Output: "ok"}}
	if _, err := collect(Executor{Agent: runner}.Execute(context.Background(), &a2asrv.ExecutorContext{})); err == nil {
		t.Fatal("expected an error for a nil message")
	}
	message := sdk.NewMessage(sdk.MessageRoleUser, sdk.NewRawPart([]byte("binary")))
	if _, err := collect(Executor{Agent: runner}.Execute(context.Background(), &a2asrv.ExecutorContext{Message: message})); err == nil {
		t.Fatal("expected an error for a non-text message")
	}
}

func TestCancelEmitsCanceledState(t *testing.T) {
	events := Executor{}.Cancel(context.Background(), &a2asrv.ExecutorContext{
		ContextID: "context-1",
		TaskID:    "task-1",
	})
	var emitted []sdk.Event
	for event, err := range events {
		if err != nil {
			t.Fatal(err)
		}
		emitted = append(emitted, event)
	}
	if len(emitted) != 1 {
		t.Fatalf("events = %d", len(emitted))
	}
	status, ok := emitted[0].(*sdk.TaskStatusUpdateEvent)
	if !ok || status.Status.State != sdk.TaskStateCanceled {
		t.Fatalf("event = %#v", emitted[0])
	}
}

func collect(events func(yield func(sdk.Event, error) bool)) ([]sdk.Event, error) {
	var out []sdk.Event
	for event, err := range events {
		if err != nil {
			return out, err
		}
		out = append(out, event)
	}
	return out, nil
}

func TestJSONRPCClientRoundTrip(t *testing.T) {
	runner := &fakeRunner{result: &agent.Result{Output: "agent reply"}}
	handler := a2asrv.NewJSONRPCHandler(a2asrv.NewHandler(Executor{Agent: runner}))
	server := httptest.NewServer(handler)
	defer server.Close()

	ctx := context.Background()
	client, err := a2aclient.NewFromEndpoints(ctx, []*sdk.AgentInterface{
		sdk.NewAgentInterface(server.URL, sdk.TransportProtocolJSONRPC),
	})
	if err != nil {
		t.Fatal(err)
	}
	result, err := client.SendMessage(ctx, &sdk.SendMessageRequest{
		Message: sdk.NewMessage(sdk.MessageRoleUser, sdk.NewTextPart("hello")),
	})
	if err != nil {
		t.Fatal(err)
	}
	reply, ok := result.(*sdk.Message)
	if !ok || reply.Role != sdk.MessageRoleAgent || len(reply.Parts) != 1 {
		t.Fatalf("result = %#v", result)
	}
	if text := reply.Parts[0].Text(); text != "agent reply" {
		t.Fatalf("text = %q", text)
	}
}

func TestGRPCClientRoundTrip(t *testing.T) {
	runner := &fakeRunner{result: &agent.Result{Output: "grpc reply"}}
	listener := bufconn.Listen(1 << 20)
	server := grpc.NewServer()
	a2agrpc.NewHandler(a2asrv.NewHandler(Executor{Agent: runner})).RegisterWith(server)
	go func() { _ = server.Serve(listener) }()
	defer server.Stop()

	ctx := context.Background()
	dialer := func(context.Context, string) (net.Conn, error) { return listener.Dial() }
	factory := a2aclient.NewFactory(a2agrpc.WithGRPCTransport(
		grpc.WithContextDialer(dialer),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	))
	client, err := factory.CreateFromCard(ctx, &sdk.AgentCard{
		Name: "gRPC Test Agent",
		SupportedInterfaces: []*sdk.AgentInterface{
			sdk.NewAgentInterface("passthrough:///bufnet", sdk.TransportProtocolGRPC),
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	result, err := client.SendMessage(ctx, &sdk.SendMessageRequest{
		Message: sdk.NewMessage(sdk.MessageRoleUser, sdk.NewTextPart("hello")),
	})
	if err != nil {
		t.Fatal(err)
	}
	reply, ok := result.(*sdk.Message)
	if !ok || reply.Role != sdk.MessageRoleAgent || len(reply.Parts) != 1 {
		t.Fatalf("result = %#v", result)
	}
	if text := reply.Parts[0].Text(); text != "grpc reply" {
		t.Fatalf("text = %q", text)
	}
}
