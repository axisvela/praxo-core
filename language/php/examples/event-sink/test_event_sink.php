<?php

declare(strict_types=1);

require __DIR__ . '/event_sink.php';

$allSink = new RecordingSink();
$toolSink = new RecordingSink();
$output = EventSinkExample::run($allSink, $toolSink);

if ($output !== 'status: green') {
    throw new RuntimeException("unexpected output: {$output}");
}
if ($allSink->types() !== ['run.started', 'tool.call', 'run.completed']) {
    throw new RuntimeException('unexpected events: ' . implode(',', $allSink->types()));
}
if ($toolSink->types() !== ['tool.call']) {
    throw new RuntimeException('unexpected filtered events: ' . implode(',', $toolSink->types()));
}
if (($toolSink->events[0]->data['name'] ?? null) !== 'lookup') {
    throw new RuntimeException('tool name missing');
}

echo "php event sink tests passed\n";
