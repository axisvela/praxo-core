<?php

declare(strict_types=1);

namespace Praxo\Core;

final class Json
{
    public static function decode(string $text): mixed
    {
        if (trim($text) === '') {
            return null;
        }
        return json_decode($text, true, 512, JSON_THROW_ON_ERROR);
    }

    public static function encode(mixed $value): string
    {
        return json_encode(
            $value,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR,
        );
    }

    public static function get(mixed $node, string $key): mixed
    {
        return is_array($node) && array_key_exists($key, $node) ? $node[$key] : null;
    }

    public static function string(mixed $node, string $key, ?string $fallback = null): ?string
    {
        $value = self::get($node, $key);
        return is_string($value) ? $value : $fallback;
    }

    public static function bool(mixed $node, string $key, bool $fallback = false): bool
    {
        $value = self::get($node, $key);
        return is_bool($value) ? $value : $fallback;
    }

    public static function int(mixed $node, string $key, int $fallback = 0): int
    {
        $value = self::get($node, $key);
        return is_int($value) ? $value : (is_float($value) ? (int) $value : $fallback);
    }

    public static function array(mixed $node, string $key): array
    {
        $value = self::get($node, $key);
        return is_array($value) ? $value : [];
    }

    public static function equals(mixed $left, mixed $right): bool
    {
        if (is_array($left) && is_array($right)) {
            if (count($left) !== count($right)) {
                return false;
            }
            foreach ($left as $key => $value) {
                if (!array_key_exists($key, $right) || !self::equals($value, $right[$key])) {
                    return false;
                }
            }
            return true;
        }
        if ((is_int($left) || is_float($left)) && (is_int($right) || is_float($right))) {
            return (float) $left === (float) $right;
        }
        return $left === $right;
    }

    public static function normalizeEmpty(array $values): mixed
    {
        return $values === [] ? null : array_values($values);
    }
}
