<?php

declare(strict_types=1);

require __DIR__ . '/../src/autoload.php';

use Praxo\Core\PluginProcessConfig;
use Praxo\Core\PluginProcessHost;

$python = PHP_OS_FAMILY === 'Windows' ? 'C:\\Python314\\python.exe' : 'python3';
$host = new PluginProcessHost(new PluginProcessConfig(
    'com.example.echo',
    $python,
    [__DIR__ . '/fixtures/process_plugin.py'],
));
$host->start();
try {
    $response = $host->invoke('tool.provider', 'echo', '{"text":"hi"}');
    if ($response !== '{"text":"hi"}') {
        throw new RuntimeException('unexpected response: ' . $response);
    }
    echo "php plugin process tests passed\n";
} finally {
    $host->stop();
}
