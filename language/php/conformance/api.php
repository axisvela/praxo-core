<?php

declare(strict_types=1);

namespace Praxo\Conformance;

function apiSnapshot(): string
{
    $classes = array_values(array_filter(
        get_declared_classes(),
        static fn (string $class): bool => str_starts_with($class, 'Praxo\\Core\\'),
    ));
    sort($classes, SORT_STRING);
    $lines = [];
    foreach ($classes as $class) {
        $reflection = new \ReflectionClass($class);
        $lines[] = '### ' . $class;
        $members = [];
        $constructor = $reflection->getConstructor();
        if ($constructor !== null && $constructor->isPublic()) {
            $members[] = $reflection->getShortName() . '(' . parameters($constructor) . ')';
        }
        foreach ($reflection->getMethods(\ReflectionMethod::IS_PUBLIC) as $method) {
            if ($method->getDeclaringClass()->getName() !== $class || $method->isConstructor()) {
                continue;
            }
            $returns = $method->getReturnType();
            $members[] = ($returns ? (string) $returns . ' ' : '') . $method->getName() . '(' . parameters($method) . ')';
        }
        foreach ($reflection->getProperties(\ReflectionProperty::IS_PUBLIC) as $property) {
            if ($property->getDeclaringClass()->getName() !== $class) {
                continue;
            }
            $type = $property->getType();
            $members[] = ($type ? (string) $type . ' ' : '') . '$' . $property->getName();
        }
        sort($members, SORT_STRING);
        foreach ($members as $member) {
            $lines[] = $member;
        }
    }
    return implode("\n", $lines) . "\n";
}

function checkApi(): int
{
    $path = repoRoot() . '/language/php/api/0.1.0.txt';
    if (!is_file($path)) {
        fwrite(STDERR, "missing API snapshot: {$path}\n");
        return 2;
    }
    $expected = str_replace("\r\n", "\n", (string) file_get_contents($path));
    $actual = str_replace("\r\n", "\n", apiSnapshot());
    if ($expected === $actual) {
        echo "api snapshot ok\n";
        return 0;
    }
    fwrite(STDERR, "api snapshot mismatch; run: php language/php/conformance/run.php --api-snapshot > language/php/api/0.1.0.txt\n");
    return 1;
}

function parameters(\ReflectionFunctionAbstract $function): string
{
    $parts = [];
    foreach ($function->getParameters() as $parameter) {
        $type = $parameter->getType();
        $parts[] = ($type ? (string) $type . ' ' : '') . '$' . $parameter->getName();
    }
    return implode(', ', $parts);
}
