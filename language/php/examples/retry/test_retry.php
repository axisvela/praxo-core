<?php

declare(strict_types=1);

require __DIR__ . '/retry.php';

use Praxo\Core\PraxoException;

$recovered = new FlakyModel(2);
if (RetryExample::run($recovered) !== 'status: green' || $recovered->calls !== 3) {
    throw new RuntimeException('transient retry path failed');
}

$exhausted = new FlakyModel(3);
try {
    RetryExample::run($exhausted);
    throw new RuntimeException('exhausted retry did not fail');
} catch (PraxoException $error) {
    if ($error->praxoCode !== 'MODEL_UNAVAILABLE' || $exhausted->calls !== 3) {
        throw new RuntimeException('exhausted retry path failed');
    }
}

echo "php retry tests passed\n";
