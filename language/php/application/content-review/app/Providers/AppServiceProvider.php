<?php

declare(strict_types=1);

namespace App\Providers;

use App\Contracts\ArticleStore;
use App\Services\FixtureArticleStore;
use Illuminate\Support\ServiceProvider;

final class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(ArticleStore::class, FixtureArticleStore::class);
    }
}
