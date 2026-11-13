<?php

declare(strict_types=1);

namespace Praxo\Core\Adapters;

use Praxo\Core\Event;
use Praxo\Core\EventSink;
use Praxo\Core\Json;
use Praxo\Core\PraxoException;

final class OtelSink implements EventSink
{
    private const MAX_BODY = 512;

    public function __construct(
        private readonly string $endpoint = 'http://127.0.0.1:4318/v1/traces',
        private readonly string $serviceName = 'praxo-core',
        private $transport = null,
        private readonly array $allowedDataKeys = [],
        private readonly int $timeout = 10,
    ) {
    }

    public function emit(Event $event): void
    {
        $data = is_array($event->data) ? $event->data : [];
        $at = $event->at ?? gmdate('Y-m-d\TH:i:s\Z');
        $key = implode('|', [
            $event->sessionId,
            $event->runId ?? '',
            $event->type,
            $at,
            Json::encode($data),
        ]);
        $traceId = $this->hex32($this->fnv1a($key, 2166136261))
            . $this->hex32($this->fnv1a($key, 3307539480))
            . $this->hex32($this->fnv1a($key, 1540483477))
            . $this->hex32($this->fnv1a($key, 2807494644));
        $spanKey = $key . '|span';
        $spanId = $this->hex32($this->fnv1a($spanKey, 2166136261))
            . $this->hex32($this->fnv1a($spanKey, 3307539480));
        $attributes = [$this->attribute('praxo.event.type', $event->type)];
        if ($event->sessionId !== '') {
            $attributes[] = $this->attribute('praxo.session.id', $event->sessionId);
        }
        if ($event->runId !== null && $event->runId !== '') {
            $attributes[] = $this->attribute('praxo.run.id', $event->runId);
        }
        $attributes[] = $this->attribute('praxo.event.at', $at);
        foreach ($this->allowedDataKeys as $name) {
            if (array_key_exists($name, $data)) {
                $attributes[] = $this->attribute(
                    'praxo.event.data.' . $name,
                    $this->text($data[$name]),
                );
            }
        }
        $nanos = sprintf('%.0f', microtime(true) * 1_000_000_000);
        $payload = [
            'resourceSpans' => [[
                'resource' => [
                    'attributes' => [$this->attribute('service.name', $this->serviceName)],
                ],
                'scopeSpans' => [[
                    'scope' => ['name' => 'praxo-core'],
                    'spans' => [[
                        'traceId' => $traceId,
                        'spanId' => $spanId,
                        'name' => 'praxo.' . $event->type,
                        'kind' => 1,
                        'startTimeUnixNano' => $nanos,
                        'endTimeUnixNano' => $nanos,
                        'attributes' => $attributes,
                    ]],
                ]],
            ]],
        ];
        $body = Json::encode($payload);
        $headers = ['content-type' => 'application/json'];
        $response = $this->transport !== null
            ? ($this->transport)($this->endpoint, $body, $headers)
            : $this->post($body, $headers);
        $status = (int) ($response['status'] ?? 0);
        if ($status >= 200 && $status < 300) {
            return;
        }
        $bounded = substr((string) ($response['body'] ?? ''), 0, self::MAX_BODY);
        throw new PraxoException('OTEL_HTTP', "otel: HTTP {$status}: {$bounded}");
    }

    private function attribute(string $key, string $value): array
    {
        return ['key' => $key, 'value' => ['stringValue' => $value]];
    }

    private function text(mixed $value): string
    {
        return is_string($value) ? $value : Json::encode($value);
    }

    private function fnv1a(string $text, int $seed): int
    {
        $value = $seed & 0xFFFFFFFF;
        $length = strlen($text);
        for ($index = 0; $index < $length; $index++) {
            $value ^= ord($text[$index]);
            $value = ($value * 16777619) & 0xFFFFFFFF;
        }
        return $value;
    }

    private function hex32(int $value): string
    {
        return sprintf('%08x', $value & 0xFFFFFFFF);
    }

    private function post(string $body, array $headers): array
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
        $responseBody = @file_get_contents($this->endpoint, false, $context);
        if ($responseBody === false) {
            throw new PraxoException('OTEL_HTTP', 'otel: request failed');
        }
        $statusLine = $http_response_header[0] ?? '';
        $status = preg_match('/\s(\d{3})\s/', $statusLine, $matches) === 1
            ? (int) $matches[1] : 0;
        return ['status' => $status, 'body' => $responseBody];
    }
}
