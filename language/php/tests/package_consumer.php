<?php

declare(strict_types=1);

require __DIR__ . '/vendor/autoload.php';
require __DIR__ . '/starter.php';

use Praxo\Core\PluginCallException;
use Praxo\Core\Agent;
use Praxo\Core\PluginProcessConfig;
use Praxo\Core\PluginProcessHost;

$package = realpath(__DIR__ . '/vendor/axisvela/praxo-core');
foreach ([Agent::class, PluginProcessConfig::class, PluginProcessHost::class, PluginCallException::class] as $class) {
    $source = (new ReflectionClass($class))->getFileName();
    if ($package === false || $source === false
        || !str_starts_with(realpath($source), $package . DIRECTORY_SEPARATOR)) {
        throw new RuntimeException('class was not loaded from the installed package: ' . $class);
    }
}

$host = new PluginProcessHost(new PluginProcessConfig('com.example.echo', PHP_BINARY));
if ($host->isActive()) {
    throw new RuntimeException('plugin host unexpectedly active');
}
try {
    $host->invoke('tool.provider', 'echo');
    throw new RuntimeException('inactive plugin host accepted a call');
} catch (PluginCallException $error) {
    if ($error->callCode !== 'NOT_ACTIVE') {
        throw $error;
    }
}

Starter::run();
echo "isolated installed package passed\n";
