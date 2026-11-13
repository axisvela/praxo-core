       01 px-subagent-request.
          05 px-sub-parent-session-id pic x(128).
          05 px-sub-parent-session-id-length binary-long.
          05 px-sub-agent-id pic x(128).
          05 px-sub-agent-id-length binary-long.
          05 px-sub-prompt pic x(2048).
          05 px-sub-prompt-length binary-long.
          05 px-sub-mode pic x(16).
          05 px-sub-mode-length binary-long.
          05 px-sub-task-id pic x(128).
          05 px-sub-task-id-length binary-long.
          05 px-sub-created-at pic x(64).
          05 px-sub-updated-at pic x(64).
          05 px-sub-runner-program pic x(64).
       01 px-subagent-result.
          05 px-sub-result-task-id pic x(128).
          05 px-sub-result-task-id-length binary-long.
          05 px-sub-result-agent-id pic x(128).
          05 px-sub-result-agent-id-length binary-long.
          05 px-sub-result-output pic x(2048).
          05 px-sub-result-output-length binary-long.
       01 px-subagent-task.
          05 px-task-id pic x(128).
          05 px-task-id-length binary-long.
          05 px-task-parent-session-id pic x(128).
          05 px-task-agent-id pic x(128).
          05 px-task-mode pic x(16).
          05 px-task-status pic x(16).
          05 px-task-output pic x(2048).
          05 px-task-output-length binary-long.
          05 px-task-error pic x(64).
          05 px-task-created-at pic x(64).
          05 px-task-updated-at pic x(64).
