<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../src/autoload.php';
}

use Praxo\Core\CheckpointAllowlist;
use Praxo\Core\PraxoException;

$allow = new CheckpointAllowlist();
$allow->register('order');
$encoded = $allow->marshal('order', ['value' => 'x']);
$decoded = $allow->unmarshal($encoded);
if ($decoded !== ['value' => 'x']) {
    throw new RuntimeException('checkpoint payload did not round trip');
}

try {
    $allow->marshal('missing', []);
    throw new RuntimeException('unregistered type was accepted');
} catch (PraxoException $error) {
    if ($error->praxoCode !== 'CHECKPOINT_TYPE_NOT_ALLOWED') {
        throw $error;
    }
}

echo "PHP checkpoint example passed\n";
