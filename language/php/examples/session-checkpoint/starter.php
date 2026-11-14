<?php

declare(strict_types=1);

$autoload = __DIR__ . '/vendor/autoload.php';
if (is_file($autoload)) {
    require $autoload;
} else {
    require __DIR__ . '/../../src/autoload.php';
}

use Praxo\Core\Agent;
use Praxo\Core\AgentOptions;
use Praxo\Core\CheckpointAllowlist;
use Praxo\Core\Message;
use Praxo\Core\Model;
use Praxo\Core\Request;
use Praxo\Core\Response;
use Praxo\Core\Roles;
use Praxo\Core\Session;

final class TurnModel implements Model
{
    public function generate(Request $request): Response
    {
        return new Response(Message::assistant('turn ' . count($request->messages)));
    }
}

function wireMessages(Session $session): array
{
    return array_map(
        static fn (Message $message): array => [
            'role' => $message->role,
            'content' => $message->content,
        ],
        $session->messages,
    );
}

function restoreMessages(array $items): array
{
    return array_map(
        static fn (array $item): Message => new Message(
            (string) $item['role'],
            $item['content'] === null ? null : (string) $item['content'],
        ),
        $items,
    );
}

$allowlist = new CheckpointAllowlist();
$allowlist->register('session');
$session = new Session(
    'session-1',
    messages: [
        new Message(Roles::USER, 'first'),
        new Message(Roles::ASSISTANT, 'ack'),
    ],
);
$payload = $allowlist->marshal('session', ['messages' => wireMessages($session)]);

$stored = $allowlist->unmarshal($payload);
$session->messages = restoreMessages($stored['messages']);
$result = (new Agent(new AgentOptions(new TurnModel())))->run($session, 'second');
if ($result->output !== 'turn 3') {
    throw new RuntimeException("unexpected second turn: {$result->output}");
}

$session->messages[] = new Message(Roles::USER, 'second');
$session->messages[] = new Message(Roles::ASSISTANT, $result->output);
$payload = $allowlist->marshal('session', ['messages' => wireMessages($session)]);

$stored = $allowlist->unmarshal($payload);
$session->messages = restoreMessages($stored['messages']);
$result = (new Agent(new AgentOptions(new TurnModel())))->run($session, 'third');
if ($result->output !== 'turn 5') {
    throw new RuntimeException("unexpected third turn: {$result->output}");
}

echo 'restored messages: ' . count($session->messages) . "\n";
echo 'output: ' . $result->output . "\n";
