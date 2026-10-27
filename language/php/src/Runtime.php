<?php

declare(strict_types=1);

namespace Praxo\Core;

interface PolicyHook
{
    public function authorize(Action $action): Decision;
}

final class PathChecker
{
    private const ACCESS = ['read', 'write', 'readwrite'];

    /** @var list<PathGrant> */
    private array $grants = [];

    /**
     * @param list<PathGrant> $grants
     */
    public function __construct(array $grants)
    {
        foreach ($grants as $grant) {
            if ($grant->root === '') {
                throw PraxoException::policy('policy: path grant root is required');
            }
            if (!in_array($grant->access, self::ACCESS, true)) {
                throw PraxoException::policy("policy: invalid grant access {$grant->access}");
            }
            $this->grants[] = new PathGrant(self::resolve($grant->root), $grant->access);
        }
    }

    public function check(string $target, string $need): Decision
    {
        if (!in_array($need, self::ACCESS, true)) {
            throw PraxoException::policy("policy: invalid requested access {$need}");
        }
        if ($this->grants === []) {
            return Decision::deny('no allowed roots');
        }
        $resolved = self::resolve($target);
        $matched = null;
        foreach ($this->grants as $grant) {
            if (!self::within($grant->root, $resolved)) {
                continue;
            }
            $matched = $grant->root;
            if (self::allows($grant->access, $need)) {
                return Decision::allow("path within {$grant->root}");
            }
        }
        return $matched !== null
            ? Decision::deny("path within {$matched} but the grant is insufficient")
            : Decision::deny('path outside allowed roots');
    }

    public function allowed(string $target, string $need): bool
    {
        try {
            return $this->check($target, $need)->allowed;
        } catch (PraxoException) {
            return false;
        }
    }

    private static function resolve(string $value): string
    {
        $real = realpath($value);
        if ($real !== false) {
            return $real;
        }
        $parent = dirname($value);
        if ($parent === $value) {
            return $value;
        }
        return rtrim(self::resolve($parent), '/\\') . DIRECTORY_SEPARATOR . basename($value);
    }

    private static function within(string $root, string $target): bool
    {
        $root = rtrim($root, '/\\');
        $target = rtrim($target, '/\\');
        $comparison = DIRECTORY_SEPARATOR === '\\' ? strcasecmp($root, $target) : strcmp($root, $target);
        if ($comparison === 0) {
            return true;
        }
        $prefix = $root . DIRECTORY_SEPARATOR;
        return DIRECTORY_SEPARATOR === '\\'
            ? strncasecmp($target, $prefix, strlen($prefix)) === 0
            : str_starts_with($target, $prefix);
    }

    private static function allows(string $grant, string $need): bool
    {
        return match ($need) {
            'read' => $grant === 'read' || $grant === 'readwrite',
            'write' => $grant === 'write' || $grant === 'readwrite',
            default => $grant === 'readwrite',
        };
    }
}

final class InMemoryMemoryStore
{
    /** @var array<string, list<MemoryRecord>> */
    private array $records = [];
    private int $sequence = 0;

    public function put(string $sessionId, MemoryRecord $record): void
    {
        if ($record->id === '') {
            $record->id = 'mem-' . (int) floor(microtime(true) * 1000) . '-' . $this->sequence++;
        }
        $record->createdAt ??= gmdate('Y-m-d\TH:i:s\Z');
        $this->records[$sessionId][] = $record;
    }

    /**
     * @return list<MemoryRecord>
     */
    public function search(string $sessionId, string $query, int $limit): array
    {
        $items = $this->records[$sessionId] ?? [];
        $needle = trim($query);
        $matches = array_values(array_filter(
            $items,
            static fn (MemoryRecord $record): bool => $needle === ''
                || stripos($record->content, $needle) !== false,
        ));
        usort($matches, static fn (MemoryRecord $left, MemoryRecord $right): int
            => strcmp($right->createdAt ?? '', $left->createdAt ?? ''));
        if ($limit > 0) {
            $matches = array_slice($matches, 0, $limit);
        }
        return $matches;
    }
}

final class CheckpointAllowlist
{
    /** @var array<string, true> */
    private array $registered = [];

    public function register(string $type): void
    {
        if ($type === '') {
            throw PraxoException::checkpoint('checkpoint: allowlist type name is required');
        }
        $this->registered[$type] = true;
    }

    public function marshal(string $type, mixed $value): string
    {
        if (!isset($this->registered[$type])) {
            throw PraxoException::typeNotAllowed("checkpoint: payload type not allowed: {$type}");
        }
        return Json::encode(['type' => $type, 'data' => $value]);
    }

    public function unmarshal(string $data): mixed
    {
        try {
            $envelope = Json::decode($data);
        } catch (\JsonException $error) {
            throw PraxoException::checkpoint('checkpoint: ' . $error->getMessage());
        }
        if (!is_array($envelope)) {
            throw PraxoException::checkpoint('checkpoint: envelope must be an object');
        }
        $type = Json::string($envelope, 'type') ?? '';
        if (!isset($this->registered[$type])) {
            throw PraxoException::typeNotAllowed("checkpoint: payload type not allowed: {$type}");
        }
        return Json::get($envelope, 'data');
    }
}

final class ContextEstimator
{
    public const COMPACT_MARKER_PREFIX = '[context compacted:';

    /**
     * @param list<Message> $messages
     */
    public static function estimateTokens(array $messages): int
    {
        $total = 0;
        foreach ($messages as $message) {
            $total += 4 + intdiv(strlen($message->content ?? ''), 4)
                + intdiv(strlen($message->toolId ?? ''), 4);
            foreach ($message->contentBlocks as $block) {
                $total += 4 + intdiv(strlen($block->text ?? ''), 4)
                    + intdiv(strlen($block->imageUrl ?? ''), 4)
                    + intdiv(strlen($block->data ?? ''), 4);
            }
            foreach ($message->toolCalls as $call) {
                $total += 4 + intdiv(strlen($call->name), 4);
                $total += intdiv(strlen(Json::encode($call->arguments)), 4);
            }
        }
        return $total;
    }

    public static function truncateToTokens(string $value, int $tokens): string
    {
        if ($tokens <= 0) {
            return '';
        }
        $limit = $tokens * 4;
        if (strlen($value) <= $limit) {
            return $value;
        }
        if ($limit <= 16) {
            return substr($value, 0, $limit);
        }
        return substr($value, 0, $limit - 16) . "\n[truncated]";
    }
}

final class ContextBudget
{
    public function __construct(
        public int $maxTokens,
        public int $keepRecent,
    ) {
    }

    /**
     * @param list<Message> $messages
     * @return array{0: list<Message>, 1: bool}
     */
    public function compact(array $messages): array
    {
        if ($this->maxTokens === 0 || ContextEstimator::estimateTokens($messages) <= $this->maxTokens) {
            return [$messages, true];
        }
        $system = [];
        $rest = [];
        foreach ($messages as $message) {
            if ($message->role === Roles::SYSTEM) {
                if (str_starts_with($message->content ?? '', ContextEstimator::COMPACT_MARKER_PREFIX)) {
                    continue;
                }
                $system[] = $message;
            } else {
                $rest[] = $message;
            }
        }
        if (ContextEstimator::estimateTokens($system) > $this->maxTokens) {
            if ($system === []) {
                return [[], false];
            }
            $first = $system[0];
            $system = [new Message(
                role: $first->role,
                content: ContextEstimator::truncateToTokens(
                    $first->content ?? '',
                    max(0, $this->maxTokens - 4),
                ),
                contentBlocks: $first->contentBlocks,
                toolCalls: $first->toolCalls,
                toolId: $first->toolId,
            )];
            if (ContextEstimator::estimateTokens($system) > $this->maxTokens) {
                return [[], false];
            }
        }
        $keep = $this->keepRecent > 0 ? $this->keepRecent : 4;
        $start = max(0, count($rest) - $keep);
        while ($start > 0 && $rest[$start]->role === Roles::TOOL) {
            $start--;
        }
        $marker = Message::text(
            Roles::SYSTEM,
            ContextEstimator::COMPACT_MARKER_PREFIX . " {$start} older messages omitted]",
        );
        $kept = array_slice($rest, $start);
        $output = $this->build($system, $marker, $start > 0, $kept);
        while (ContextEstimator::estimateTokens($output) > $this->maxTokens && count($kept) > 1) {
            if ($kept[1]->role === Roles::TOOL) {
                break;
            }
            array_shift($kept);
            $output = $this->build($system, $marker, $start > 0, $kept);
        }
        return ContextEstimator::estimateTokens($output) > $this->maxTokens
            ? [[], false]
            : [$output, true];
    }

    /**
     * @param list<Message> $system
     * @param list<Message> $kept
     * @return list<Message>
     */
    private function build(array $system, Message $marker, bool $includeMarker, array $kept): array
    {
        $output = $system;
        if ($includeMarker) {
            $output[] = $marker;
        }
        foreach ($kept as $message) {
            $output[] = $message;
        }
        return $output;
    }
}

interface EventSink
{
    public function emit(Event $event): void;
}

final class MultiSink implements EventSink
{
    /** @param list<EventSink> $sinks */
    public function __construct(private array $sinks)
    {
    }

    public function emit(Event $event): void
    {
        foreach ($this->sinks as $sink) {
            $sink->emit($event);
        }
    }
}

final class FilterSink implements EventSink
{
    public function __construct(
        private EventSink $sink,
        /** @var callable(Event): bool */
        private $predicate,
    ) {
    }

    public function emit(Event $event): void
    {
        if (($this->predicate)($event)) {
            $this->sink->emit($event);
        }
    }
}
