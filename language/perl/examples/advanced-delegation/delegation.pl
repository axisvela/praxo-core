use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Praxo::Agent ();
use Praxo::Models ();

my %effects;

package DemoRecordTool;

sub new { bless { effects => $_[1] }, $_[0] }
sub name { 'record' }
sub description { 'Record a target in an in-memory counter' }
sub parameters {
    return {
        type => 'object',
        properties => { target => { type => 'string' } },
        required => ['target'],
    };
}
sub invoke {
    my ($self, $arguments) = @_;
    my $target = $arguments->{target} // '';
    $self->{effects}{$target} = ($self->{effects}{$target} // 0) + 1;
    return { recorded => $target };
}

package DemoModel;

sub new {
    my ($class, %args) = @_;
    return bless {
        steps => [ @{ $args{steps} // [] } ],
        final => $args{final} // '',
    }, $class;
}

sub generate {
    my ($self) = @_;
    if (@{ $self->{steps} }) {
        my $step = shift @{ $self->{steps} };
        return Praxo::Models::response(
            message => Praxo::Models::message_assistant(
                $step->{content} // '',
                $step->{tool_calls} // [],
            ),
        );
    }
    return Praxo::Models::response(
        message => Praxo::Models::message_assistant($self->{final}),
    );
}

package DemoDelegateTool;

sub new {
    my ($class, %args) = @_;
    return bless {
        record => $args{record},
        effects => $args{effects},
        child_model => $args{child_model},
    }, $class;
}

sub name { 'delegate' }
sub description { 'Run a child agent with a narrowed record scope' }
sub parameters {
    return {
        type => 'object',
        properties => { task => { type => 'string' } },
        required => ['task'],
    };
}

sub invoke {
    my ($self) = @_;
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($self->{record});
    my $options = Praxo::Agent::AgentOptions->new($self->{child_model});
    $options->{tools} = $registry;
    $options->{max_steps} = 3;
    $options->{allowed_tools} = ['record'];
    $options->{policy} = sub {
        my ($action) = @_;
        return Praxo::Models::decision(allowed => 1)
            if ($action->{kind} // '') eq 'model.generate';
        return Praxo::Models::decision(allowed => 1)
            if ($action->{kind} // '') eq 'tool.invoke'
                && ($action->{toolName} // '') eq 'record';
        return Praxo::Models::decision(allowed => 0, reason => 'child may only record');
    };
    $options->{require_policy} = 1;
    $options->{require_tool_scope} = 1;
    my $child = Praxo::Agent::Agent->new($options);
    my $result = $child->run(Praxo::Models::session(id => 'demo-child'), 'record child');
    return { output => $result->{output}, effects => $self->{effects}{child} // 0 };
}

package main;

sub parent_policy {
    my ($action) = @_;
    my $kind = $action->{kind} // '';
    return Praxo::Models::decision(allowed => 1) if $kind eq 'model.generate';
    return Praxo::Models::decision(allowed => 1)
        if $kind eq 'tool.invoke' && ($action->{toolName} // '') eq 'delegate';
    return Praxo::Models::decision(allowed => 0, reason => 'parent may only delegate');
}

my $record = DemoRecordTool->new(\%effects);
my $child_model = DemoModel->new(
    steps => [
        {
            tool_calls => [
                Praxo::Models::tool_call(
                    id => 'child-record',
                    name => 'record',
                    arguments => { target => 'child' },
                ),
            ],
        },
    ],
    final => 'child done',
);
my $delegate = DemoDelegateTool->new(
    record => $record,
    effects => \%effects,
    child_model => $child_model,
);
my $parent_model = DemoModel->new(
    steps => [
        {
            tool_calls => [
                Praxo::Models::tool_call(
                    id => 'parent-delegate',
                    name => 'delegate',
                    arguments => { task => 'record child' },
                ),
            ],
        },
    ],
    final => 'parent done',
);

my $registry = Praxo::Agent::ToolRegistry->new;
$registry->register($record);
$registry->register($delegate);
my $options = Praxo::Agent::AgentOptions->new($parent_model);
$options->{tools} = $registry;
$options->{allowed_tools} = ['delegate'];
$options->{policy} = \&parent_policy;
$options->{require_policy} = 1;
$options->{require_tool_scope} = 1;
my $agent = Praxo::Agent::Agent->new($options);
my $result = $agent->run(Praxo::Models::session(id => 'demo-parent'), 'delegate');
print 'delegation: child recorded; parent scope enforced', "\n";

my $direct_model = DemoModel->new(
    steps => [
        {
            tool_calls => [
                Praxo::Models::tool_call(
                    id => 'direct-record',
                    name => 'record',
                    arguments => { target => 'child' },
                ),
            ],
        },
    ],
    final => 'parent done',
);
my $direct_options = Praxo::Agent::AgentOptions->new($direct_model);
$direct_options->{tools} = $registry;
$direct_options->{allowed_tools} = ['delegate'];
$direct_options->{policy} = \&parent_policy;
$direct_options->{require_policy} = 1;
$direct_options->{require_tool_scope} = 1;
my $direct_agent = Praxo::Agent::Agent->new($direct_options);
my $error;
eval {
    $direct_agent->run(Praxo::Models::session(id => 'demo-direct'), 'record directly');
    1;
} or $error = $@;
print 'deny: parent record blocked; child effect unchanged', "\n";
die "delegation example failed\n"
    unless $result->{output} eq 'parent done'
        && ($effects{child} // 0) == 1
        && defined $error;
