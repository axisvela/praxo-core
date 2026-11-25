<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Services\EditorialAgent;
use App\Services\ReviewFailure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class ArticleReviewController
{
    public function __construct(private readonly EditorialAgent $agent)
    {
    }

    public function __invoke(Request $request, string $article): JsonResponse
    {
        try {
            $result = $this->agent->review(
                (string) $request->header('X-Tenant-Id'),
                $article,
            );

            return response()->json($result->toArray());
        } catch (ReviewFailure $failure) {
            $status = match ($failure->errorCode) {
                'AGENT_POLICY_DENIED', 'AGENT_TOOL_NOT_ALLOWED' => 403,
                'TOOL_ERROR' => 503,
                default => 500,
            };

            return response()->json($failure->toArray(), $status);
        }
    }
}
