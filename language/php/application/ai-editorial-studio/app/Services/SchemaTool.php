<?php

declare(strict_types=1);

namespace App\Services;

use Praxo\Core\Tool;
use Praxo\Core\ToolSpec;

final class SchemaTool implements Tool
{
    private \Closure $function;

    /** @param array<string, mixed> $parameters */
    public function __construct(
        private readonly string $toolName,
        private readonly string $toolDescription,
        private readonly array $parameters,
        callable $function,
    ) {
        $this->function = \Closure::fromCallable($function);
    }

    public function name(): string
    {
        return $this->toolName;
    }

    public function description(): string
    {
        return $this->toolDescription;
    }

    public function spec(): ToolSpec
    {
        return new ToolSpec($this->toolName, $this->toolDescription, $this->parameters, 'low');
    }

    public function invoke(array $arguments): mixed
    {
        return ($this->function)($arguments);
    }
}
