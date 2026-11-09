package longrunning

import (
	"bytes"
	"context"
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

func TestLongRunningExecutionChild(t *testing.T) {
	path := os.Getenv("PRAXO_EXECUTION_CHILD_PATH")
	if path == "" {
		t.Skip("subprocess helper only")
	}
	journal, err := openExecutionJournal(path)
	if err != nil {
		t.Fatal(err)
	}
	stage := os.Getenv("PRAXO_EXECUTION_CRASH_STAGE")
	journal.commitHook = func(at string) error {
		if at == stage {
			os.Exit(93)
		}
		return nil
	}
	_, err = journal.Run(context.Background(), "operation-1", "digest-1", func(context.Context) error {
		file, err := os.OpenFile(path+".calls", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
		if err != nil {
			return err
		}
		_, writeErr := file.WriteString("invoked\n")
		return errors.Join(writeErr, file.Close())
	})
	t.Fatalf("child did not reach crash boundary: %v", err)
}

func TestLongRunningExecutionProcessCrash(t *testing.T) {
	for _, test := range []struct {
		stage, want string
		calls       int
	}{
		{"admission.after-rename", executionAdmitted, 0},
		{"start.after-rename", executionUnknown, 0},
		{"finish.after-rename", executionCompleted, 1},
	} {
		t.Run(test.stage, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "execution.json")
			executable, err := os.Executable()
			if err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			command := exec.CommandContext(ctx, executable, "-test.run=^TestLongRunningExecutionChild$")
			command.Env = append(os.Environ(), "PRAXO_EXECUTION_CHILD_PATH="+path, "PRAXO_EXECUTION_CRASH_STAGE="+test.stage)
			command.WaitDelay = time.Second
			output, err := command.CombinedOutput()
			var exited *exec.ExitError
			if !errors.As(err, &exited) || exited.ExitCode() != 93 {
				t.Fatalf("child did not exit at injected boundary: %v %s", err, output)
			}
			journal, err := openExecutionJournal(path)
			if err != nil {
				t.Fatal(err)
			}
			record, err := journal.Run(context.Background(), "operation-1", "digest-1", func(context.Context) error {
				t.Fatal("reopened process state re-invoked executor")
				return nil
			})
			if record.State != test.want || (err != nil && !errors.Is(err, errExecutionUnknown)) {
				t.Fatalf("record=%+v err=%v", record, err)
			}
			calls, err := os.ReadFile(path + ".calls")
			if err != nil && !os.IsNotExist(err) {
				t.Fatal(err)
			}
			if count := bytes.Count(calls, []byte("invoked\n")); count != test.calls {
				t.Fatalf("executor entry count=%d want=%d", count, test.calls)
			}
		})
	}
}
