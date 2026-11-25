<?php

declare(strict_types=1);

return [
    'tenant' => env('CONTENT_TENANT', 'acme'),
    'brief_max' => (int) env('CONTENT_BRIEF_MAX', 500),
    'store_failure' => (bool) env('CONTENT_STORE_FAILURE', false),
    'model' => [
        'base_url' => env('PRAXO_BASE_URL'),
        'api_key' => env('PRAXO_API_KEY'),
        'name' => env('PRAXO_MODEL'),
    ],
];
