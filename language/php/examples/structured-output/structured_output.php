<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../src/autoload.php';
}

use Praxo\Core\JsonSchema;

$schema = json_decode(
    '{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}',
    true,
    flags: JSON_THROW_ON_ERROR
);
$valid = json_decode('{"name":"ok"}', true, flags: JSON_THROW_ON_ERROR);
$invalid = json_decode('{}', true, flags: JSON_THROW_ON_ERROR);

if (JsonSchema::validate($schema, $valid) !== []) {
    throw new RuntimeException('valid output was rejected');
}
if (JsonSchema::validate($schema, $invalid) === []) {
    throw new RuntimeException('invalid output was accepted');
}

echo "PHP structured output example passed\n";
