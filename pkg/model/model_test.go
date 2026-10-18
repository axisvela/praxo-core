package model

import "testing"

func TestEchoProvider(t *testing.T) {
	var p Provider = EchoProvider{}
	msgs, err := p.Chat([]Message{{Role: RoleUser, Content: "hello"}})
	if err != nil || len(msgs) != 1 || msgs[0].Content != "hello" {
		t.Fatalf("msgs = %+v, err = %v", msgs, err)
	}
	stream, err := p.ChatStream([]Message{{Role: RoleUser, Content: "hi"}})
	if err != nil {
		t.Fatal(err)
	}
	event := <-stream
	if event.Delta != "hi" || !event.Done {
		t.Fatalf("event = %+v", event)
	}
}

func TestSingleProviderRouter(t *testing.T) {
	r := SingleProviderRouter{Provider: EchoProvider{}}
	if _, err := r.Route(TaskChat); err != nil {
		t.Fatal(err)
	}
}
