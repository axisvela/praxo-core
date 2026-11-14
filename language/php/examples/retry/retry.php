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

final class FlakyModel implements Model
{
    public int $calls = 0;

    public function __construct(private readonly int $failures)
    {
    }

    public function generate(Request $request): Response
    {
        $this->calls++;
        if ($this->calls <= $this->failures) {
            throw new PraxoException('MODEL_UNAVAILABLE', 'temporary outage');
        }
        return new Response(Message::assistant('status: green'));
    }
}

final class RetryExample
{
    public static function middleware(int $maxAttempts = 3): callable
    {
        return static function (callable $next) use ($maxAttempts): callable {
            return static function (Request $request) use ($next, $maxAttempts): Response {
                $last = null;
                for ($attempt = 1; $attempt <= $maxAttempts; $attempt++) {
                    try {
                        return $next($request);
                    } catch (\Throwable $error) {
                        if (!($error instanceof PraxoException)
                            || $error->praxoCode !== 'MODEL_UNAVAILABLE') {
                            throw $error;
                        }
                        $last = $error;
                        if ($attempt === $maxAttempts) {
                            throw $error;
                        }
                    }
                }
                throw $last ?? new PraxoException('MODEL_UNAVAILABLE', 'model unavailable');
            };
        };
    }

    public static function run(Model $model, int $maxAttempts = 3): string
    {
        $options = new AgentOptions($model);
        $options->modelMiddleware[] = self::middleware($maxAttempts);
        $options->maxSteps = 2;
        return (new Agent($options))
            ->run(new Session('retry'), 'Check the status.')
            ->output;
    }
}
