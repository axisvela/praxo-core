<?php

declare(strict_types=1);

use App\Http\Controllers\EditorialDraftController;
use Illuminate\Support\Facades\Route;

Route::post('/editorial/drafts', EditorialDraftController::class)
    ->middleware('tenant')
    ->name('editorial.drafts');
