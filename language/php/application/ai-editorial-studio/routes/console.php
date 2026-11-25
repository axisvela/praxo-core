<?php

declare(strict_types=1);

use App\Services\EditorialAgent;
use App\Services\ReviewFailure;
use Illuminate\Support\Facades\Artisan;

Artisan::command(
    'content:draft-article {brief?} {--simulate-failure}',
    function (?string $brief = null): int {
        $brief = $brief ?: 'Write a Q3 service update for the news section.';

        if ($this->option('simulate-failure')) {
            config(['content.store_failure' => true]);
        }

        try {
            $result = app(EditorialAgent::class)->review(
                (string) config('content.tenant'),
                $brief,
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
)->purpose('Generate a review-only editorial draft from a brief');
