<?php

declare(strict_types=1);

namespace Praxo\Core\Adapters;

use Praxo\Core\Event;
use Praxo\Core\EventSink;
use Praxo\Core\Json;
use Praxo\Core\PraxoException;

final class HarmovelaSink implements EventSink
{
    private const MAX_BODY = 1024;

    public function __construct(
        private readonly string $baseUrl,
        private readonly ?string $source = null,
        private readonly ?string $specVersion = null,
        private $transport = null,
        private $clock = null,
        private readonly int $timeout = 10,
    ) {
    }

    public function emit(Event $event): void
    {
        if ($this->baseUrl === '') {
            throw new PraxoException('HARMOVELA_URL', 'harmovela: base URL is required');
        }
        [$seconds, $nanos] = $this->now();
        $payload = is_array($event->data) ? $event->data : [];
        if ($event->sessionId !== '') {
            $payload['session_id'] = $event->sessionId;
        }
        if ($event->runId !== null && $event->runId !== '') {
            $payload['run_id'] = $event->runId;
        }
        $envelope = [
            'spec_version' => $this->specVersion(),
            'id' => $this->eventId($event, $seconds, $nanos),
            'type' => $event->type,
            'source' => $this->source(),
            'created_at' => $this->createdAt($seconds, $nanos),
            'payload' => $payload,
        ];
        $body = Json::encode($envelope);
        $headers = ['content-type' => 'application/json'];
        $response = $this->transport !== null
            ? ($this->transport)('/events', $body, $headers)
            : $this->post('/events', $body, $headers);
        $status = (int) ($response['status'] ?? 0);
        if ($status >= 200 && $status < 300) {
            return;
        }
        $bounded = substr((string) ($response['body'] ?? ''), 0, self::MAX_BODY);
        throw new PraxoException('HARMOVELA_HTTP', "harmovela: HTTP {$status}: {$bounded}");
    }

    private function source(): string
    {
        return $this->source === null || $this->source === '' ? 'praxo-core' : $this->source;
    }

    private function specVersion(): string
    {
        return $this->specVersion === null || $this->specVersion === '' ? '0.2' : $this->specVersion;
    }

    private function now(): array
    {
        if ($this->clock !== null) {
            return ($this->clock)();
        }
        $now = gettimeofday();
        return [(int) $now['sec'], (int) $now['usec'] * 1000];
    }

    private function eventId(Event $event, int $seconds, int $nanos): string
    {
        $prefix = $event->runId !== null && $event->runId !== '' ? $event->runId : $event->sessionId;
        if ($prefix === '') {
            $prefix = 'event';
        }
        return $prefix . '-' . ($seconds * 1_000_000_000 + $nanos);
    }

    private function createdAt(int $seconds, int $nanos): string
    {
        return gmdate('Y-m-d\TH:i:s', $seconds) . '.' . sprintf('%09d', $nanos) . 'Z';
    }

    private function post(string $path, string $body, array $headers): array
    {
        $headerLines = '';
        foreach ($headers as $name => $value) {
            $headerLines .= $name . ': ' . $value . "\r\n";
        }
        $context = stream_context_create([
            'http' => [
                'method' => 'POST',
                'header' => $headerLines,
                'content' => $body,
                'timeout' => $this->timeout,
                'ignore_errors' => true,
            ],
        ]);
        $url = rtrim($this->baseUrl, '/') . $path;
        $responseBody = @file_get_contents($url, false, $context);
        if ($responseBody === false) {
            throw new PraxoException('HARMOVELA_HTTP', 'harmovela request failed');
        }
        $statusLine = $http_response_header[0] ?? '';
        $status = preg_match('/\s(\d{3})\s/', $statusLine, $matches) === 1 ? (int) $matches[1] : 0;
        return ['status' => $status, 'body' => $responseBody];
    }
}
