<?php

declare(strict_types=1);

namespace Praxo\Core;

final class PluginProcessConfig
{
    public function __construct(
        public string $pluginId,
        public string $path,
        public array $args = [],
        public ?string $token = null,
        public string $tokenEnvVar = 'PRAXOVELA_PLUGIN_TOKEN',
        public float $startTimeout = 10.0,
        public float $invokeTimeout = 30.0,
    ) {
    }
}

final class PluginCallException extends \RuntimeException
{
    public function __construct(public string $callCode, string $message = '')
    {
        parent::__construct($message !== '' ? $message : $callCode);
    }
}

final class PluginProcessHost
{
    private const PROTOCOL_VERSION = 1;
    private const CONTROL_SERVICE = 'host.control';

    private string $token;
    private mixed $process = null;
    private array $pipes = [];
    private int $seq = 0;
    private bool $active = false;

    public function __construct(private PluginProcessConfig $config)
    {
        if ($config->pluginId === '') {
            throw new PraxoException('PLUGIN_INVALID', 'plugin: PluginID is required');
        }
        if ($config->path === '') {
            throw new PraxoException('PLUGIN_INVALID', 'plugin: path is required');
        }
        $this->token = $config->token ?? bin2hex(random_bytes(32));
    }

    public function isActive(): bool
    {
        return $this->active;
    }

    public function start(): void
    {
        if ($this->process !== null) {
            throw new PraxoException('PLUGIN_INVALID', 'plugin: host already started');
        }
        $command = [$this->config->path, ...$this->config->args];
        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['file', PHP_OS_FAMILY === 'Windows' ? 'NUL' : '/dev/null', 'a'],
        ];
        $environment = getenv();
        $environment = is_array($environment) ? $environment : [];
        foreach (['PATH', 'Path', 'SystemRoot'] as $key) {
            $value = getenv($key);
            if ($value !== false && !array_key_exists($key, $environment)) {
                $environment[$key] = $value;
            }
        }
        $environment[$this->config->tokenEnvVar] = $this->token;
        $process = proc_open($command, $descriptors, $pipes, null, $environment);
        if (!is_resource($process)) {
            throw new PraxoException('PLUGIN_START', 'plugin: start failed');
        }
        $this->process = $process;
        $this->pipes = $pipes;
        try {
            $this->call(self::CONTROL_SERVICE, 'health', '');
        } catch (\Throwable $error) {
            $this->stop();
            throw $error;
        }
        $this->active = true;
    }

    public function invoke(string $service, string $method, string $payload = ''): string
    {
        if (!$this->active) {
            throw new PluginCallException('NOT_ACTIVE', 'plugin: host is not active');
        }
        return $this->call($service, $method, $payload);
    }

    public function stop(): void
    {
        if ($this->process === null) {
            return;
        }
        if ($this->active) {
            try {
                $this->call(self::CONTROL_SERVICE, 'shutdown', '');
            } catch (\Throwable) {
            }
        }
        $this->active = false;
        foreach ($this->pipes as $pipe) {
            if (is_resource($pipe)) {
                fclose($pipe);
            }
        }
        proc_terminate($this->process);
        proc_close($this->process);
        $this->pipes = [];
        $this->process = null;
    }

    private function call(string $service, string $method, string $payload): string
    {
        $this->seq++;
        $frame = [
            'id' => 'req-' . $this->seq,
            'version' => self::PROTOCOL_VERSION,
            'plugin_id' => $this->config->pluginId,
            'service' => $service,
            'method' => $method,
            'token' => $this->token,
            'payload' => base64_encode($payload),
        ];
        $line = Json::encode($frame) . "\n";
        if (fwrite($this->pipes[0], $line) === false) {
            throw new PluginCallException('INTERNAL', 'plugin: write failed');
        }
        fflush($this->pipes[0]);
        $responseLine = fgets($this->pipes[1]);
        if ($responseLine === false) {
            throw new PluginCallException('INTERNAL', 'plugin: process closed the stream');
        }
        $response = Json::decode($responseLine);
        if (Json::get($response, 'ok') !== true) {
            $code = Json::string($response, 'code') ?? 'INTERNAL';
            $message = Json::string($response, 'message') ?? 'plugin: call failed';
            throw new PluginCallException($code, $message);
        }
        $encoded = Json::string($response, 'payload') ?? '';
        return $encoded === '' ? '' : (base64_decode($encoded, true) ?: '');
    }
}
