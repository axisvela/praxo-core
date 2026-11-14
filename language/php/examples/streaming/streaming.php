<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../src/autoload.php';
}

use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\Message;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Session;
use Praxo\Core\StreamingModel;

final class FakeStreamingModel implements StreamingModel
{
    /** @param list<string> $chunks */
    public function __construct(private readonly array $chunks)
    {
    }

    public function generate(Request $request): Response
    {
        return new Response(Message::assistant(implode('', $this->chunks)));
    }

    public function generateStream(Request $request, callable $onDelta): Response
    {
        foreach ($this->chunks as $chunk) {
            $onDelta($chunk);
        }
        return $this->generate($request);
    }
}

$chunks = ['status: ', 'green'];
$received = [];
$options = new AgentOptions(new FakeStreamingModel($chunks));
$options->maxSteps = 2;
$output = (new Agent($options))
    ->runStream(new Session('streaming'), 'Check the status.', function (string $delta) use (&$received): void {
        $received[] = $delta;
    })
    ->output;

if ($output !== 'status: green' || $received !== $chunks || implode('', $received) !== $output) {
    throw new RuntimeException('streaming deltas did not reconstruct the output');
}

echo "PHP streaming example passed\n";
