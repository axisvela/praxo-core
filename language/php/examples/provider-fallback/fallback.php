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
use Praxo\Core\Model;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Session;

final class StaticModel implements Model
{
    public int $calls = 0;

    public function __construct(private readonly string $content)
    {
    }

    public function generate(Request $request): Response
    {
        $this->calls++;
        return new Response(Message::assistant($this->content));
    }
}

final class FailingModel implements Model
{
    public int $calls = 0;

    public function generate(Request $request): Response
    {
        $this->calls++;
        throw new PraxoException('MODEL_UNAVAILABLE', 'primary unavailable');
    }
}

final class ProviderFallbackExample
{
    public static function run(Model $primary, Model $fallback): string
    {
        $options = new AgentOptions($primary);
        $options->fallbackModel = $fallback;
        $options->maxSteps = 2;
        return (new Agent($options))
            ->run(new Session('provider-fallback'), 'Say hello.')
            ->output;
    }
}
