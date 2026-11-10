<?php

declare(strict_types=1);

namespace Praxo\Conformance;

function typeName(\ReflectionType|null $type, string $class): string
{
    if ($type === null) {
        return '';
    }
    return preg_replace('/\bself\b/', $class, (string) $type) ?? (string) $type;
}

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
            $members[] = $reflection->getShortName() . '(' . parameters($constructor, $class) . ')';
        }
        foreach ($reflection->getMethods(\ReflectionMethod::IS_PUBLIC) as $method) {
            if ($method->getDeclaringClass()->getName() !== $class || $method->isConstructor()) {
                continue;
            }
            $returns = typeName($method->getReturnType(), $class);
            $members[] = ($returns !== '' ? $returns . ' ' : '') . $method->getName() . '(' . parameters($method, $class) . ')';
        }
        foreach ($reflection->getProperties(\ReflectionProperty::IS_PUBLIC) as $property) {
            if ($property->getDeclaringClass()->getName() !== $class) {
                continue;
            }
            $type = typeName($property->getType(), $class);
            $members[] = ($type !== '' ? $type . ' ' : '') . '$' . $property->getName();
        }
        sort($members, SORT_STRING);
        foreach ($members as $member) {
            $lines[] = $member;
        }
    }
    return implode("\n", $lines) . "\n";
}

function packageVersion(): string
{
    $manifest = json_decode(
        (string) file_get_contents(dirname(__DIR__) . '/composer.json'),
        true,
        flags: JSON_THROW_ON_ERROR,
    );
    $version = is_array($manifest) ? ($manifest['version'] ?? null) : null;
    if (!is_string($version) || $version === '') {
        throw new \RuntimeException('composer.json: missing version');
    }
    return $version;
}

function checkApi(): int
{
    $version = packageVersion();
    $path = repoRoot() . '/language/php/api/' . $version . '.txt';
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
    fwrite(STDERR, "api snapshot mismatch; run: php language/php/conformance/run.php --api-snapshot > language/php/api/{$version}.txt\n");
    return 1;
}

function parameters(\ReflectionFunctionAbstract $function, string $class): string
{
    $parts = [];
    foreach ($function->getParameters() as $parameter) {
        $type = typeName($parameter->getType(), $class);
        $parts[] = ($type !== '' ? $type . ' ' : '') . '$' . $parameter->getName();
    }
    return implode(', ', $parts);
}
