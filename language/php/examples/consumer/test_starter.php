<?php

declare(strict_types=1);

require __DIR__ . '/starter.php';

[$output, $calls, $error] = Starter::runScenario('public');
if ($error !== null || $output !== 'recorded' || $calls !== 1) {
    throw new RuntimeException("allow: output={$output} effects={$calls} error={$error?->getMessage()}");
}

[, $calls, $error] = Starter::runScenario('private');
if ($error === null || $error->praxoCode !== 'AGENT_POLICY_DENIED' || $calls !== 0) {
    throw new RuntimeException("deny: effects={$calls} error={$error?->getMessage()}");
}

echo "php consumer tests passed\n";
