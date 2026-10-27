<?php

declare(strict_types=1);

namespace Praxo\Core;

final class ParsedToolCall
{
    public function __construct(
        public string $callId = '',
        public string $name = '',
        public array $input = [],
        public string $operation = '',
        public string $resource = '',
        public string $risk = '',
        public string $reason = '',
        public string $idempotencyKey = '',
    ) {
    }
}

final class ToolCallParser
{
    public static function parse(string $content): ?ParsedToolCall
    {
        $call = self::parseJson($content)
            ?? self::parseXml($content)
            ?? self::parseTag($content)
            ?? self::parsePlain($content);
        if ($call !== null) {
            $call->callId = 'tc-' . (int) floor(microtime(true) * 1000);
        }
        return $call;
    }

    public static function stripMarkup(string $content): string
    {
        $patterns = [
            '~<tool_call\s+name="[^"]+"\s*>.*?(?:</tool_call>|$)~s',
            '~<tool_call_invoke>.*?(?:</tool_call_invoke>|$)~s',
            '~<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{.*?(?:</[a-zA-Z][\w.-]*>|$)~s',
        ];
        $output = $content;
        foreach ($patterns as $pattern) {
            $output = preg_replace($pattern, '', $output) ?? $output;
        }
        $output = preg_replace("~\n{3,}~", "\n\n", $output) ?? $output;
        return trim($output);
    }

    public static function parseInputJson(string $raw): ?array
    {
        try {
            $value = Json::decode(trim($raw));
            if (is_array($value)) {
                return $value;
            }
        } catch (\JsonException) {
        }
        try {
            $value = Json::decode(trim(str_replace('\\', '\\\\', $raw)));
            if (is_array($value)) {
                return $value;
            }
        } catch (\JsonException) {
        }
        return null;
    }

    private static function parseJson(string $content): ?ParsedToolCall
    {
        try {
            $root = Json::decode($content);
        } catch (\JsonException) {
            return null;
        }
        if (!is_array($root)) {
            return null;
        }
        $name = Json::string($root, 'name');
        if ($name === null || $name === '') {
            return null;
        }
        return new ParsedToolCall(
            name: $name,
            input: is_array(Json::get($root, 'input')) ? Json::get($root, 'input') : [],
            operation: Json::string($root, 'operation') ?? '',
            resource: Json::string($root, 'resource') ?? '',
            risk: Json::string($root, 'risk') ?? '',
            reason: Json::string($root, 'reason') ?? '',
            idempotencyKey: Json::string($root, 'idempotency_key') ?? '',
        );
    }

    private static function parseXml(string $content): ?ParsedToolCall
    {
        if (preg_match_all('~<tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</tool_call>~s', $content, $matches, PREG_SET_ORDER) === 0) {
            return null;
        }
        $match = $matches[array_key_last($matches)];
        $input = self::parseInputJson($match[2]);
        return $input === null ? null : new ParsedToolCall(name: $match[1], input: $input);
    }

    private static function parseTag(string $content): ?ParsedToolCall
    {
        $pattern = '~<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{.*?)\s*(?:</[a-zA-Z][\w.-]*>|$)~s';
        if (preg_match_all($pattern, $content, $matches, PREG_SET_ORDER) === 0) {
            return null;
        }
        $match = $matches[array_key_last($matches)];
        $input = self::parseInputJson($match[2]);
        return $input === null ? null : new ParsedToolCall(name: $match[1], input: $input);
    }

    private static function parsePlain(string $content): ?ParsedToolCall
    {
        if (preg_match_all('~^\s*([a-zA-Z][\w.-]*)\s+(\{.*\})\s*$~m', $content, $matches, PREG_SET_ORDER) === 0) {
            return null;
        }
        $match = $matches[array_key_last($matches)];
        if (!str_contains($match[1], '.')) {
            return null;
        }
        $input = self::parseInputJson($match[2]);
        return $input === null ? null : new ParsedToolCall(name: $match[1], input: $input);
    }
}

final class ValidationError
{
    public function __construct(
        public string $path,
        public string $message,
    ) {
    }
}

final class JsonSchema
{
    public static function validate(mixed $schema, mixed $data): array
    {
        $errors = [];
        self::visit(is_array($schema) ? $schema : [], $data, '$', $errors);
        return $errors;
    }

    private static function visit(array $schema, mixed $data, string $path, array &$errors): void
    {
        $kind = Json::string($schema, 'type') ?? '';
        if ($data === null) {
            if ($kind !== '') {
                $errors[] = new ValidationError($path, "expected {$kind}, got null");
            }
            return;
        }
        match ($kind) {
            'object' => self::visitObject($schema, $data, $path, $errors),
            'array' => self::visitArray($schema, $data, $path, $errors),
            'string' => self::visitString($schema, $data, $path, $errors),
            'number', 'integer' => self::visitNumber($schema, $kind, $data, $path, $errors),
            'boolean' => self::visitBoolean($schema, $data, $path, $errors),
            default => null,
        };
    }

    private static function visitObject(array $schema, mixed $data, string $path, array &$errors): void
    {
        if (!is_array($data)) {
            $errors[] = new ValidationError($path, 'expected object');
            return;
        }
        foreach (Json::array($schema, 'required') as $name) {
            if (is_string($name) && !array_key_exists($name, $data)) {
                $errors[] = new ValidationError("{$path}.{$name}", 'required field missing');
            }
        }
        $properties = Json::get($schema, 'properties');
        if (!is_array($properties)) {
            return;
        }
        foreach ($properties as $name => $child) {
            if (is_array($child) && array_key_exists($name, $data)) {
                self::visit($child, $data[$name], "{$path}.{$name}", $errors);
            }
        }
    }

    private static function visitArray(array $schema, mixed $data, string $path, array &$errors): void
    {
        if (!is_array($data)) {
            $errors[] = new ValidationError($path, 'expected array');
            return;
        }
        $items = Json::get($schema, 'items');
        if (is_array($items)) {
            foreach ($data as $index => $value) {
                self::visit($items, $value, "{$path}[{$index}]", $errors);
            }
        }
    }

    private static function visitString(array $schema, mixed $data, string $path, array &$errors): void
    {
        if (!is_string($data)) {
            $errors[] = new ValidationError($path, 'expected string');
            return;
        }
        $length = preg_match_all('/./us', $data, $matches);
        $length = $length === false ? strlen($data) : $length;
        $min = Json::int($schema, 'minLength');
        $max = Json::int($schema, 'maxLength');
        if ($min > 0 && $length < $min) {
            $errors[] = new ValidationError($path, "min length {$min}, got {$length}");
        }
        if ($max > 0 && $length > $max) {
            $errors[] = new ValidationError($path, "max length {$max}, got {$length}");
        }
        $pattern = Json::string($schema, 'pattern');
        if ($pattern !== null && @preg_match('~' . str_replace('~', '\~', $pattern) . '~u', $data) !== 1) {
            $errors[] = new ValidationError($path, "pattern '{$pattern}' not matched");
        }
        self::checkEnum($schema, $data, $path, $errors);
    }

    private static function visitNumber(array $schema, string $kind, mixed $data, string $path, array &$errors): void
    {
        if (!is_int($data) && !is_float($data)) {
            $errors[] = new ValidationError($path, 'expected number');
            return;
        }
        if ($kind === 'integer' && (float) $data !== floor((float) $data)) {
            $errors[] = new ValidationError($path, "expected integer, got {$data}");
            return;
        }
        self::checkEnum($schema, $data, $path, $errors);
        $minimum = Json::get($schema, 'minimum');
        $maximum = Json::get($schema, 'maximum');
        if (is_int($minimum) || is_float($minimum)) {
            if ((float) $minimum !== 0.0 && $data < $minimum) {
                $errors[] = new ValidationError($path, 'value below minimum');
            }
        }
        if (is_int($maximum) || is_float($maximum)) {
            if ((float) $maximum !== 0.0 && $data > $maximum) {
                $errors[] = new ValidationError($path, 'value above maximum');
            }
        }
    }

    private static function visitBoolean(array $schema, mixed $data, string $path, array &$errors): void
    {
        if (!is_bool($data)) {
            $errors[] = new ValidationError($path, 'expected boolean');
            return;
        }
        self::checkEnum($schema, $data, $path, $errors);
    }

    private static function checkEnum(array $schema, mixed $data, string $path, array &$errors): void
    {
        $values = Json::get($schema, 'enum');
        if (!is_array($values) || $values === []) {
            return;
        }
        foreach ($values as $value) {
            if (Json::equals($value, $data)) {
                return;
            }
        }
        $errors[] = new ValidationError($path, 'value not in enum');
    }
}

final class PluginManifest
{
    public function __construct(
        public int $schemaVersion = 0,
        public string $id = '',
        public string $version = '',
        public string $kind = '',
        public array $entrypoint = [],
        public string $protocol = '',
        public array $capabilities = [],
        public array $permissions = [],
        public array $limits = [],
        public string $isolation = '',
        public array $health = [],
        public ?array $signature = null,
        public string $sbom = '',
    ) {
    }
}

final class Plugin
{
    public const KINDS = [
        'tool.provider.v1', 'model.provider.v1', 'policy.provider.v1',
        'memory.provider.v1', 'sandbox.provider.v1',
    ];

    private const TOP_KEYS = [
        'schemaVersion', 'id', 'version', 'kind', 'entrypoint', 'protocol',
        'capabilities', 'permissions', 'limits', 'isolation', 'health',
        'signature', 'sbom',
    ];

    private const ENTRYPOINT_KEYS = ['type', 'command', 'module', 'image', 'args', 'dir'];
    private const PERMISSION_KEYS = ['filesystem', 'network', 'env'];
    private const LIMIT_KEYS = ['memoryMB', 'cpuMillis', 'timeoutMs', 'maxInflight'];
    private const HEALTH_KEYS = ['method', 'intervalMs'];
    private const SIGNATURE_KEYS = ['algorithm', 'keyId'];

    public static function parseManifest(string $raw): PluginManifest
    {
        if (trim($raw) === '') {
            throw PraxoException::plugin('plugin: manifest is empty');
        }
        try {
            $root = json_decode($raw, true, 512, JSON_THROW_ON_ERROR);
        } catch (\JsonException $error) {
            throw PraxoException::plugin('plugin: manifest: ' . $error->getMessage());
        }
        if (!is_array($root)) {
            throw PraxoException::plugin('plugin: manifest must be an object');
        }
        self::checkKeys($root, self::TOP_KEYS, 'manifest');
        $schemaVersion = self::asInt(Json::get($root, 'schemaVersion'), 'schemaVersion');
        if ($schemaVersion !== 1) {
            throw PraxoException::plugin("plugin: manifest: schemaVersion = {$schemaVersion}, want 1");
        }
        $id = self::asString(Json::get($root, 'id'), 'id');
        if (preg_match('~^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$~', $id) !== 1) {
            throw PraxoException::plugin("plugin: manifest: id {$id} is not reverse-DNS");
        }
        $version = self::asString(Json::get($root, 'version'), 'version');
        if (preg_match('~^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$~', $version) !== 1) {
            throw PraxoException::plugin("plugin: manifest: version {$version} is not semver");
        }
        $kind = self::asString(Json::get($root, 'kind'), 'kind');
        if (!in_array($kind, self::KINDS, true)) {
            throw PraxoException::plugin("plugin: manifest: kind {$kind} is not a known contract");
        }
        $protocol = self::asString(Json::get($root, 'protocol'), 'protocol');
        if ($protocol !== 'jsonrpc-2') {
            throw PraxoException::plugin("plugin: manifest: protocol = {$protocol}, want jsonrpc-2");
        }
        $entrypoint = self::asObject(Json::get($root, 'entrypoint'), 'entrypoint');
        self::checkKeys($entrypoint, self::ENTRYPOINT_KEYS, 'entrypoint');
        $entryType = self::asString(Json::get($entrypoint, 'type'), 'entrypoint.type');
        $required = match ($entryType) {
            'process' => 'command',
            'wasm' => 'module',
            'container' => 'image',
            default => throw PraxoException::plugin("plugin: manifest: unknown entrypoint type {$entryType}"),
        };
        if (!self::textPresent(Json::get($entrypoint, $required))) {
            throw PraxoException::plugin("plugin: manifest: {$entryType} entrypoint requires {$required}");
        }
        $isolation = self::asString(Json::get($root, 'isolation'), 'isolation');
        if ($isolation !== $entryType) {
            throw PraxoException::plugin("plugin: manifest: isolation {$isolation} does not match entrypoint {$entryType}");
        }
        $permissions = self::asObject(Json::get($root, 'permissions'), 'permissions');
        self::checkKeys($permissions, self::PERMISSION_KEYS, 'permissions');
        $limits = self::asObject(Json::get($root, 'limits'), 'limits');
        self::checkKeys($limits, self::LIMIT_KEYS, 'limits');
        foreach ($limits as $key => $value) {
            if (self::asInt($value, "limits.{$key}") < 0) {
                throw PraxoException::plugin('plugin: manifest: limits must not be negative');
            }
        }
        $health = self::asObject(Json::get($root, 'health'), 'health');
        self::checkKeys($health, self::HEALTH_KEYS, 'health');
        $signature = Json::get($root, 'signature');
        $signatureObject = null;
        if ($signature !== null) {
            $signatureObject = self::asObject($signature, 'signature');
            self::checkKeys($signatureObject, self::SIGNATURE_KEYS, 'signature');
            if (!self::textPresent(Json::get($signatureObject, 'algorithm'))
                || !self::textPresent(Json::get($signatureObject, 'keyId'))) {
                throw PraxoException::plugin('plugin: manifest: signature requires algorithm and keyId');
            }
        }
        $capabilities = [];
        $rawCapabilities = Json::get($root, 'capabilities');
        if ($rawCapabilities !== null) {
            if (!is_array($rawCapabilities)) {
                throw PraxoException::plugin('plugin: manifest: capabilities must be an array');
            }
            foreach ($rawCapabilities as $item) {
                $capabilities[] = self::asString($item, 'capabilities');
            }
        }
        if (in_array('', $capabilities, true)) {
            throw PraxoException::plugin('plugin: manifest: capability must not be empty');
        }
        if (count($capabilities) !== count(array_unique($capabilities))) {
            throw PraxoException::plugin('plugin: manifest: duplicate capability');
        }
        return new PluginManifest(
            schemaVersion: $schemaVersion,
            id: $id,
            version: $version,
            kind: $kind,
            entrypoint: $entrypoint,
            protocol: $protocol,
            capabilities: $capabilities,
            permissions: $permissions,
            limits: $limits,
            isolation: $isolation,
            health: $health,
            signature: $signatureObject,
            sbom: Json::string($root, 'sbom') ?? '',
        );
    }

    private static function checkKeys(array $value, array $allowed, string $where): void
    {
        foreach (array_keys($value) as $key) {
            if (!in_array($key, $allowed, true)) {
                throw PraxoException::plugin("plugin: manifest: unknown field {$key} in {$where}");
            }
        }
    }

    private static function asObject(mixed $value, string $where): array
    {
        if ($value === null) {
            return [];
        }
        if (!is_array($value)) {
            throw PraxoException::plugin("plugin: manifest: {$where} must be an object");
        }
        return $value;
    }

    private static function asString(mixed $value, string $where): string
    {
        if (!is_string($value)) {
            throw PraxoException::plugin("plugin: manifest: {$where} must be a string");
        }
        return $value;
    }

    private static function asInt(mixed $value, string $where): int
    {
        if (!is_int($value)) {
            throw PraxoException::plugin("plugin: manifest: {$where} must be an integer");
        }
        return $value;
    }

    private static function textPresent(mixed $value): bool
    {
        return is_string($value) && $value !== '';
    }
}
