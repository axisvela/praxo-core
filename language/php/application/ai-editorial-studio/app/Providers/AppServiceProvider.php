<?php

declare(strict_types=1);

namespace App\Providers;

use App\Contracts\ContentIndex;
use App\Contracts\DraftRepository;
use App\Services\FixtureContentIndex;
use App\Services\InMemoryDraftRepository;
use Illuminate\Support\ServiceProvider;

final class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(ContentIndex::class, FixtureContentIndex::class);
        $this->app->singleton(DraftRepository::class, InMemoryDraftRepository::class);
    }
}
