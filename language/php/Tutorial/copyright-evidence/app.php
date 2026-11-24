<?php
/**
 * LJ-05 copyright evidence slice: compare fixed authorized assets and draft a
 * review-only evidence packet. No crawl, automatic notice or adjudication.
 */

declare(strict_types=1);

$autoload = __DIR__ . '/../../src/autoload.php';
if (!is_file($autoload)) {
    fwrite(STDERR, "PHP Core autoload not found: {$autoload}\n");
    exit(1);
}
require $autoload;

use Praxo\Core\Action;
use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\Decision;
use Praxo\Core\FuncTool;
use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\PolicyHook;
use Praxo\Core\PraxoException;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Roles;
use Praxo\Core\Session;
use Praxo\Core\ToolCall;
use Praxo\Core\ToolRegistry;

final class CopyrightModel implements Model
{
    public function __construct(private readonly string $asset)
    {
    }

    public function generate(Request $request): Response
    {
        $results = array_values(array_filter(
            $request->messages,
            static fn (Message $message): bool => $message->role === Roles::TOOL,
        ));
        $count = count($results);
        if ($count === 0) {
            return new Response(Message::assistant('', [
                new ToolCall('assets-1', 'read_assets', ['asset' => $this->asset]),
            ]));
        }
        if ($count === 1) {
            return new Response(Message::assistant('', [
                new ToolCall('packet-1', 'draft_packet', [
                    'asset' => $this->asset,
                    'action' => 'draft_evidence',
                ]),
            ]));
        }
        $assets = json_decode($results[0]->content ?? '{}', true);
        $packet = json_decode($results[$count - 1]->content ?? '{}', true);
        $report = json_encode([
            'stage' => 'copyright_evidence_drafted',
            'assets' => $assets,
            'packet' => $packet,
            'dmca_notices' => 0,
            'adjudications' => 0,
        ]);
        return new Response(Message::assistant($report === false ? '{}' : $report));
    }
}

final class CopyrightPolicy implements PolicyHook
{
    public function authorize(Action $action): Decision
    {
        if ($action->kind === 'model.generate') {
            return Decision::allow('deterministic copyright review');
        }
        if ($action->kind !== 'tool.invoke') {
            return Decision::deny('unsupported action');
        }
        if (($action->arguments['asset'] ?? null) !== 'asset-100') {
            return Decision::deny('only asset-100 is in scope');
        }
        return match ($action->toolName) {
            'read_assets' => Decision::allow('read-only authorized fixtures'),
            'draft_packet' => ($action->arguments['action'] ?? null) === 'draft_evidence'
                ? Decision::allow('review-only evidence packet')
                : Decision::deny('only draft_evidence is allowed'),
            default => Decision::deny('unsupported tool'),
        };
    }
}

final class CopyrightTutorial
{
    /** @return array{0: ?array<string, mixed>, 1: array{reads: int, drafts: int}, 2: ?Throwable} */
    public static function run(string $asset = 'asset-100', bool $failure = false): array
    {
        $state = ['reads' => 0, 'drafts' => 0];
        $registry = new ToolRegistry();
        $registry->register(new FuncTool('read_assets', 'Compare fixed authorized assets; no crawl.', static function (array $arguments) use (&$state, $failure): array {
            if (($arguments['asset'] ?? null) !== 'asset-100') {
                throw new RuntimeException('asset not found');
            }
            $state['reads']++;
            if ($failure) {
                throw new RuntimeException('ASSET_INDEX_UNAVAILABLE');
            }
            return [
                'asset' => 'asset-100',
                'assets' => 2,
                'matches' => 1,
                'license' => 'restricted',
                'jurisdictions' => ['US'],
                'source' => 'asset_fixture',
            ];
        }));
        $registry->register(new FuncTool('draft_packet', 'Draft a review-only evidence packet; never files a notice.', static function (array $arguments) use (&$state): array {
            $state['drafts']++;
            return [
                'packet_id' => 'evidence-100',
                'asset' => $arguments['asset'],
                'action' => $arguments['action'],
                'evidences' => 2,
                'status' => 'draft_only',
                'review_required' => true,
                'dmca_notices' => 0,
                'adjudications' => 0,
            ];
        }));

        $options = new AgentOptions(new CopyrightModel($asset));
        $options->tools = $registry;
        $options->allowedTools = ['read_assets', 'draft_packet'];
        $options->policy = new CopyrightPolicy();
        $options->requirePolicy = true;
        $options->requireToolScope = true;
        $options->maxSteps = 4;

        try {
            $result = (new Agent($options))->run(
                new Session('copyright-evidence'),
                'Compare the fixed assets and draft a review-only evidence packet.',
            );
            $decoded = json_decode($result->output, true);
            return [is_array($decoded) ? $decoded : null, $state, null];
        } catch (Throwable $error) {
            return [null, $state, $error];
        }
    }

    public static function test(): void
    {
        [$report, $state, $error] = self::run();
        if ($error !== null || $state !== ['reads' => 1, 'drafts' => 1]) {
            throw new RuntimeException('success failed: ' . $error?->getMessage());
        }
        if (($report['stage'] ?? null) !== 'copyright_evidence_drafted'
            || ($report['assets']['matches'] ?? null) !== 1
            || ($report['packet']['status'] ?? null) !== 'draft_only'
            || ($report['dmca_notices'] ?? null) !== 0
            || ($report['adjudications'] ?? null) !== 0) {
            throw new RuntimeException('unexpected report: ' . json_encode($report));
        }

        [, $state, $error] = self::run('asset-200');
        if (!$error instanceof PraxoException || $error->praxoCode !== 'AGENT_POLICY_DENIED'
            || $state !== ['reads' => 0, 'drafts' => 0]) {
            throw new RuntimeException('scope denial failed: ' . $error?->getMessage());
        }

        [, $state, $error] = self::run('asset-100', true);
        if ($error === null || $state !== ['reads' => 1, 'drafts' => 0]) {
            throw new RuntimeException('dependency failure failed: ' . $error?->getMessage());
        }

        echo "PHP LJ-05 copyright-evidence tutorial: success, denial and dependency failure passed\n";
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    if (($argv[1] ?? null) === '--test') {
        CopyrightTutorial::test();
    } else {
        $asset = 'asset-100';
        $index = array_search('--asset', $argv, true);
        if ($index !== false && isset($argv[$index + 1])) {
            $asset = $argv[$index + 1];
        }
        [$report, $state, $error] = CopyrightTutorial::run(
            $asset,
            in_array('--simulate-failure', $argv, true),
        );
        if ($error !== null) {
            fwrite(STDERR, "copyright review failed: reads={$state['reads']} drafts={$state['drafts']}; {$error->getMessage()}\n");
            exit(1);
        }
        echo json_encode($report), "\n";
    }
}
