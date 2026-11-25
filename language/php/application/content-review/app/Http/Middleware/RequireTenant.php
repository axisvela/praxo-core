<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

final class RequireTenant
{
    public function handle(Request $request, Closure $next): Response
    {
        $expected = (string) config('content.tenant', 'acme');
        $actual = (string) $request->header('X-Tenant-Id', '');

        if ($actual === '') {
            return response()->json(['error' => 'TENANT_REQUIRED'], 401);
        }

        if (!hash_equals($expected, $actual)) {
            return response()->json(['error' => 'TENANT_DENIED'], 403);
        }

        $request->attributes->set('tenant', $actual);

        return $next($request);
    }
}
