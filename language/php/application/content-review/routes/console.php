<?php

declare(strict_types=1);

use App\Services\EditorialAgent;
use App\Services\ReviewFailure;
use Illuminate\Support\Facades\Artisan;

Artisan::command(
    'content:review-article {article=article-100} {--simulate-failure}',
    function (string $article): int {
        if ($this->option('simulate-failure')) {
            config(['content.store_failure' => true]);
        }

        try {
            $result = app(EditorialAgent::class)->review(
                (string) config('content.tenant'),
                $article,
            );

            $this->line((string) json_encode(
                $result->toArray(),
                JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES,
            ));

            return 0;
        } catch (ReviewFailure $failure) {
            $this->error((string) json_encode(
                $failure->toArray(),
                JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES,
            ));

            return 1;
        }
    },
)->purpose('Review one fixed article with the governed Laravel content agent');
