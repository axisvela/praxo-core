use strict;
use warnings;
use lib 'language/perl/lib';
use POSIX qw(strftime);
use Praxo::Agent ();
use Praxo::Adapters::OpenAICompatible ();
use Praxo::Models ();

sub env_or {
    my ($name, $fallback) = @_;
    my $value = $ENV{$name};
    return defined $value && $value ne '' ? $value : $fallback;
}

sub get_time {
    my ($arguments) = @_;
    if (($arguments->{zone} // 'utc') eq 'local') {
        return strftime('%Y-%m-%dT%H:%M:%S%z', localtime);
    }
    return strftime('%Y-%m-%dT%H:%M:%SZ', gmtime);
}

sub authorize {
    my ($action) = @_;
    if ($action->{kind} eq 'model.generate') {
        return Praxo::Models::decision(allowed => 1);
    }
    if ($action->{kind} eq 'tool.invoke') {
        return Praxo::Models::decision(
            allowed => ($action->{toolName} // '') eq 'get_time',
            reason => 'only get_time is permitted',
        );
    }
    return Praxo::Models::decision(allowed => 0, reason => 'unsupported action');
}

my $base_url = env_or('PRAXO_BASE_URL', 'http://localhost:11434/v1');
my $model_name = env_or('PRAXO_MODEL', 'qwen3.5:4b');
my $api_key = env_or('PRAXO_API_KEY', '');
my $prompt = env_or(
    'PRAXO_PROMPT',
    'What time is it? Use get_time with zone set to utc and reply with the time.',
);

my $registry = Praxo::Agent::ToolRegistry->new;
$registry->register(Praxo::Agent::FuncTool->new(
    'get_time',
    'Return the current time in ISO 8601 format for the requested zone.',
    \&get_time,
    {
        type => 'object',
        properties => {
            zone => {
                type => 'string',
                enum => [ 'utc', 'local' ],
                description => 'utc or local; defaults to utc',
            },
        },
    },
    'read',
));

my $options = Praxo::Agent::AgentOptions->new(
    Praxo::Adapters::OpenAICompatible->new(
        base_url => $base_url,
        model => $model_name,
        api_key => $api_key,
    ),
);
$options->{tools} = $registry;
$options->{system_prompt} =
    'You are a concise assistant. Use the provided tools when they help.';
$options->{max_steps} = 4;
$options->{allowed_tools} = ['get_time'];
$options->{policy} = \&authorize;

my $result = eval {
    Praxo::Agent::run_agent(
        $options, Praxo::Models::session(id => 'live-model'), $prompt,
    );
};
if (!$result) {
    warn "live model run failed: $@\n"
        . "Check PRAXO_BASE_URL ($base_url), PRAXO_MODEL ($model_name), and PRAXO_API_KEY\n";
    exit 1;
}
print $result->{output}, "\n";
