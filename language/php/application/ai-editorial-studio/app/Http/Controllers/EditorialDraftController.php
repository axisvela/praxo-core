<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Services\EditorialAgent;
use App\Services\ReviewFailure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

final class EditorialDraftController
{
    public function __construct(private readonly EditorialAgent $agent)
    {
    }

    public function __invoke(Request $request): JsonResponse
    {
        $data = $request->validate([
            'brief' => ['required', 'string', 'max:500'],
        ]);

        try {
            $result = $this->agent->review(
                (string) $request->header('X-Tenant-Id'),
                $data['brief'],
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
