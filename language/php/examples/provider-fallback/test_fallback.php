<?php

declare(strict_types=1);

require __DIR__ . '/fallback.php';

use Praxo\Core\PraxoException;

$primary = new StaticModel('primary response');
$fallback = new StaticModel('fallback response');
if (ProviderFallbackExample::run($primary, $fallback) !== 'primary response'
    || $fallback->calls !== 0) {
    throw new RuntimeException('primary success path failed');
}

$failing = new FailingModel();
$used = new StaticModel('fallback response');
if (ProviderFallbackExample::run($failing, $used) !== 'fallback response'
    || $failing->calls !== 1 || $used->calls !== 1) {
    throw new RuntimeException('fallback path failed');
}

try {
    ProviderFallbackExample::run(new FailingModel(), new FailingModel());
    throw new RuntimeException('both-failure path did not reject');
} catch (PraxoException $error) {
    if ($error->praxoCode !== 'MODEL_UNAVAILABLE') {
        throw $error;
    }
}

echo "PHP provider fallback tests passed\n";
