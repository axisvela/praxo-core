<?php

declare(strict_types=1);

namespace Praxo\Core;

final class SubagentRequest
{
    public function __construct(
        public string $parentSessionId,
        public string $agentId,
        public string $prompt,
        public array $context = [],
        public string $mode = 'isolated',
        public array $history = [],
    ) {
    }
}

final class SubagentResult
{
    public function __construct(
        public string $output = '',
        public string $taskId = '',
        public string $agentId = '',
        public mixed $usage = null,
    ) {
    }
}

final class SubagentTask
{
    public function __construct(
        public string $id,
        public string $parentSessionId,
        public string $agentId,
        public string $mode,
        public string $status,
        public string $output,
        public string $error,
        public string $createdAt,
        public string $updatedAt,
    ) {
    }
}

interface SubagentRunner
{
    public function run(SubagentRequest $request): SubagentResult;
}

final class SubagentManager
{
    public function __construct(private readonly SubagentRunner $runner)
    {
    }

    public function run(SubagentRequest $request): SubagentTask
    {
        if ($request->parentSessionId === '' || $request->agentId === '') {
            throw new PraxoException(
                'SUBAGENT_INVALID',
                'agent: subagent parent session and agent id are required',
            );
        }
        $now = gmdate('Y-m-d\TH:i:s\Z');
        $task = new SubagentTask(
            id: 'subagent-' . bin2hex(random_bytes(6)),
            parentSessionId: $request->parentSessionId,
            agentId: $request->agentId,
            mode: $request->mode === 'fork' ? 'fork' : 'isolated',
            status: 'running',
            output: '',
            error: '',
            createdAt: $now,
            updatedAt: $now,
        );
        try {
            $result = $this->runner->run($request);
            $task->status = 'completed';
            $task->output = $result->output;
        } catch (\Throwable $error) {
            $task->status = 'failed';
            $task->error = $error->getMessage();
        }
        $task->updatedAt = gmdate('Y-m-d\TH:i:s\Z');
        return $task;
    }
}
