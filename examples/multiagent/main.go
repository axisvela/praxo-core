package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/axisvela/praxo-core/v2/pkg/agent"
	"github.com/axisvela/praxo-core/v2/pkg/agent/delegation"
	"github.com/axisvela/praxo-core/v2/pkg/model"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	result, err := runSupervisor(ctx)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println("researcher:", result.Outputs["researcher"])
	fmt.Println("writer:", result.Outputs["writer"])
	fmt.Println("slow subagent canceled:", result.Canceled)
}

type outcome struct {
	Outputs  map[string]string
	Canceled bool
}

func runSupervisor(ctx context.Context) (outcome, error) {
	researcher, err := agent.New(agent.Options{
		Model:    staticModel{label: "research"},
		MaxSteps: 2,
	})
	if err != nil {
		return outcome{}, err
	}
	writer, err := agent.New(agent.Options{
		Model:    staticModel{label: "draft"},
		MaxSteps: 2,
	})
	if err != nil {
		return outcome{}, err
	}

	manager := delegation.NewSubagentManager(router{
		"researcher": agentRunner{agent: researcher},
		"writer":     agentRunner{agent: writer},
		"slow":       slowRunner{},
	})

	type job struct {
		name   string
		prompt string
	}
	jobs := []job{
		{name: "researcher", prompt: "find the status"},
		{name: "writer", prompt: "write the report"},
	}
	taskIDs := map[string]string{}
	for _, job := range jobs {
		task, err := manager.Launch(ctx, delegation.SubagentRequest{
			ParentSessionID: "session-1",
			AgentID:         job.name,
			Prompt:          job.prompt,
			Mode:            delegation.SubagentIsolated,
		})
		if err != nil {
			return outcome{}, err
		}
		taskIDs[job.name] = task.ID
	}

	waitCtx, waitCancel := context.WithTimeout(ctx, 2*time.Second)
	defer waitCancel()
	outputs := map[string]string{}
	for _, job := range jobs {
		task, err := manager.Wait(waitCtx, taskIDs[job.name])
		if err != nil {
			return outcome{}, fmt.Errorf("wait for %s: %w", job.name, err)
		}
		switch task.Status {
		case delegation.SubagentCompleted:
			outputs[job.name] = task.Output
		case delegation.SubagentFailed:
			return outcome{}, fmt.Errorf("%s failed: %s", job.name, task.Error)
		case delegation.SubagentCanceled:
			return outcome{}, fmt.Errorf("%s was canceled", job.name)
		default:
			return outcome{}, fmt.Errorf("%s returned status %s", job.name, task.Status)
		}
	}

	slow, err := manager.Launch(ctx, delegation.SubagentRequest{
		ParentSessionID: "session-1",
		AgentID:         "slow",
		Prompt:          "wait forever",
		Mode:            delegation.SubagentIsolated,
	})
	if err != nil {
		return outcome{}, err
	}
	if err := manager.Cancel(slow.ID); err != nil {
		return outcome{}, err
	}
	task, err := manager.Wait(ctx, slow.ID)
	if err != nil {
		return outcome{}, err
	}
	return outcome{Outputs: outputs, Canceled: task.Status == delegation.SubagentCanceled}, nil
}

type staticModel struct {
	label string
}

func (m staticModel) Generate(_ context.Context, req model.Request) (model.Response, error) {
	return model.Response{Message: model.Message{
		Role:    model.RoleAssistant,
		Content: m.label + ": " + lastUserMessage(req.Messages),
	}}, nil
}

func lastUserMessage(messages []model.Message) string {
	for i := len(messages) - 1; i >= 0; i-- {
		if messages[i].Role == model.RoleUser {
			return messages[i].Content
		}
	}
	return ""
}

type agentRunner struct {
	agent *agent.Agent
}

func (r agentRunner) Run(ctx context.Context, req delegation.SubagentRequest) (delegation.SubagentResult, error) {
	result, err := r.agent.Run(ctx, agent.Session{
		ID:       req.ParentSessionID + "/" + req.AgentID,
		Messages: req.History,
	}, req.Prompt)
	if err != nil {
		return delegation.SubagentResult{}, err
	}
	return delegation.SubagentResult{
		TaskID:  req.ParentSessionID + "/" + req.AgentID,
		AgentID: req.AgentID,
		Output:  result.Output,
		Usage:   result.Usage,
	}, nil
}

type slowRunner struct{}

func (slowRunner) Run(ctx context.Context, _ delegation.SubagentRequest) (delegation.SubagentResult, error) {
	<-ctx.Done()
	return delegation.SubagentResult{}, ctx.Err()
}

type router map[string]delegation.SubagentRunner

func (r router) Run(ctx context.Context, req delegation.SubagentRequest) (delegation.SubagentResult, error) {
	runner, ok := r[req.AgentID]
	if !ok {
		return delegation.SubagentResult{}, fmt.Errorf("unknown subagent %q", req.AgentID)
	}
	return runner.Run(ctx, req)
}
