<?php

declare(strict_types=1);

use App\Http\Controllers\ArticleReviewController;
use Illuminate\Support\Facades\Route;

Route::post('/articles/{article}/review', ArticleReviewController::class)
    ->middleware('tenant')
    ->name('articles.review');
