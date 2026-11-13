<?php

declare(strict_types=1);

namespace Praxo\Core;

final class Document
{
    public function __construct(
        public string $id,
        public string $content,
        public array $metadata = [],
        public float $score = 0.0,
    ) {
    }

    public function toWire(): array
    {
        $out = ['id' => $this->id, 'content' => $this->content];
        if ($this->metadata !== []) {
            $out['metadata'] = $this->metadata;
        }
        if ($this->score !== 0.0) {
            $out['score'] = $this->score;
        }
        return $out;
    }
}

interface Retriever
{
    /** @return list<Document> */
    public function retrieve(string $query, int $limit): array;
}

final class FuncRetriever implements Retriever
{
    public function __construct(private $retrieve)
    {
        if (!is_callable($retrieve)) {
            throw new PraxoException('RETRIEVER_INVALID', 'retriever: retrieve must be callable');
        }
    }

    public function retrieve(string $query, int $limit): array
    {
        return ($this->retrieve)($query, $limit);
    }
}
