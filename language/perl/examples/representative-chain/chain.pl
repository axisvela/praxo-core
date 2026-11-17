use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Praxo::Agent ();
use Praxo::Models ();
use Praxo::Runtime ();
use Praxo::Json ();
use Praxo::Adapters::MCP ();
use Praxo::Adapters::Otel ();
use Praxo::Adapters::Harmovela ();

package ChainRecordTool;

sub new {
    my ($class, %args) = @_;
    return bless {
        client => $args{client},
        effects => $args{effects},
    }, $class;
}

sub name { 'record' }
sub description { 'Record a target through an MCP tool' }

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
    my $result = $self->{client}->call_tool('record', { target => $target });
    return { recorded => $result };
}

package ChainScriptedModel;

sub new {
    my ($class, %args) = @_;
    return bless {
        steps => [ @{ $args{steps} // [] } ],
        final => $args{final} // '',
        calls => 0,
    }, $class;
}

sub calls { $_[0]->{calls} }

sub generate {
    my ($self, $request) = @_;
    $self->{calls}++;
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

package ChainDelegateTool;

sub new {
    my ($class, %args) = @_;
    return bless {
        record => $args{record},
        child_model => $args{child_model},
        effects => $args{effects},
        events => $args{events},
    }, $class;
}

sub name { 'delegate' }
sub description { 'Run a governed child agent with the narrowed record scope' }

sub parameters {
    return {
        type => 'object',
        properties => { task => { type => 'string' } },
        required => ['task'],
    };
}

sub invoke {
    my ($self, $arguments) = @_;
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($self->{record});
    my $options = Praxo::Agent::AgentOptions->new($self->{child_model});
    $options->{tools} = $registry;
    $options->{max_steps} = 3;
    $options->{allowed_tools} = ['record'];
    $options->{policy} = sub {
        my ($action) = @_;
        my $parent = parent_policy($action);
        return $parent unless $parent->{allowed};
        return child_policy($action);
    };
    $options->{require_policy} = 1;
    $options->{require_tool_scope} = 1;
    $options->{events} = $self->{events};
    my $child = Praxo::Agent::Agent->new($options);
    my $result = $child->run(
        Praxo::Models::session(id => 'chain-child'),
        'record child',
    );
    return {
        output => $result->{output},
        effects => $self->{effects}{child} // 0,
    };
}

sub parent_policy {
    my ($action) = @_;
    my $kind = $action->{kind} // '';
    return Praxo::Models::decision(allowed => 1) if $kind eq 'model.generate';
    return Praxo::Models::decision(allowed => 0, reason => 'unsupported action')
        unless $kind eq 'tool.invoke';
    my $name = $action->{toolName} // '';
    if ($name eq 'record') {
        my $target = ($action->{arguments} // {})->{target} // '';
        return Praxo::Models::decision(
            allowed => 0,
            reason => 'blocked target',
        ) if $target eq 'blocked';
        return Praxo::Models::decision(allowed => 1);
    }
    return Praxo::Models::decision(allowed => 1) if $name eq 'delegate';
    return Praxo::Models::decision(
        allowed => 0,
        reason => 'parent tool is not allowed',
    );
}

sub child_policy {
    my ($action) = @_;
    my $kind = $action->{kind} // '';
    return Praxo::Models::decision(allowed => 1) if $kind eq 'model.generate';
    return Praxo::Models::decision(allowed => 1)
        if $kind eq 'tool.invoke' && ($action->{toolName} // '') eq 'record';
    return Praxo::Models::decision(
        allowed => 0,
        reason => 'child may only record',
    );
}

package main;

sub tool_call {
    my (%args) = @_;
    return Praxo::Models::tool_call(
        id => $args{id},
        name => $args{name},
        arguments => $args{arguments},
    );
}

sub fake_transport {
    my ($effects) = @_;
    return sub {
        my ($method, $params) = @_;
        if ($method eq 'initialize') {
            return {
                protocolVersion => '2024-11-05',
                capabilities => { tools => {} },
                serverInfo => { name => 'fake-mcp', version => '0.0.1' },
            };
        }
        if ($method eq 'tools/list') {
            return {
                tools => [
                    {
                        name => 'record',
                        description => 'Record a target',
                        inputSchema => {
                            type => 'object',
                            properties => { target => { type => 'string' } },
                            required => ['target'],
                        },
                    },
                ],
            };
        }
        if ($method eq 'tools/call') {
            my $name = $params->{name} // '';
            my $arguments = $params->{arguments} // {};
            if ($name ne 'record') {
                return { isError => 1, content => [{ type => 'text', text => 'unknown tool' }] };
            }
            my $target = $arguments->{target} // '';
            $effects->{$target} = ($effects->{$target} // 0) + 1;
            return { content => [{ type => 'text', text => "recorded:$target" }] };
        }
        return {};
    };
}

sub otel_transport {
    my ($log) = @_;
    return sub {
        my ($endpoint, $body, $headers) = @_;
        my $payload = Praxo::Json::parse($body);
        for my $resource (@{ $payload->{resourceSpans} // [] }) {
            for my $scope (@{ $resource->{scopeSpans} // [] }) {
                for my $span (@{ $scope->{spans} // [] }) {
                    push @$log, $span->{name} // '';
                }
            }
        }
        return { status => 200, body => '' };
    };
}

sub harmovela_transport {
    my ($log) = @_;
    return sub {
        my ($path, $body, $headers) = @_;
        my $payload = Praxo::Json::parse($body);
        push @$log, $payload->{type} // '';
        return { status => 202, body => '' };
    };
}

sub run_chain {
    my %effects;
    my $client = Praxo::Adapters::MCP->new(
        transport => fake_transport(\%effects),
    );
    $client->start;
    my $record = ChainRecordTool->new(client => $client, effects => \%effects);

    my @otel_log;
    my @harmovela_log;
    my $events = Praxo::Runtime::MultiSink->new([
        Praxo::Adapters::Otel->new(
            endpoint => 'http://otel.local/v1/traces',
            transport => otel_transport(\@otel_log),
        ),
        Praxo::Adapters::Harmovela->new(
            base_url => 'http://harmovela.local',
            transport => harmovela_transport(\@harmovela_log),
        ),
    ]);

    my $child_model = ChainScriptedModel->new(
        steps => [
            {
                tool_calls => [
                    tool_call(
                        id => 'child-record',
                        name => 'record',
                        arguments => { target => 'child' },
                    ),
                ],
            },
        ],
        final => 'DONE',
    );
    my $delegate = ChainDelegateTool->new(
        record => $record,
        child_model => $child_model,
        effects => \%effects,
        events => $events,
    );

    my $parent_model = ChainScriptedModel->new(
        steps => [
            {
                tool_calls => [
                    tool_call(
                        id => 'parent-record',
                        name => 'record',
                        arguments => { target => 'parent' },
                    ),
                ],
            },
            {
                tool_calls => [
                    tool_call(
                        id => 'parent-delegate',
                        name => 'delegate',
                        arguments => { task => 'record child' },
                    ),
                ],
            },
        ],
        final => 'DONE',
    );

    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($record);
    $registry->register($delegate);

    my $options = Praxo::Agent::AgentOptions->new($parent_model);
    $options->{tools} = $registry;
    $options->{max_steps} = 4;
    $options->{allowed_tools} = ['record', 'delegate'];
    $options->{policy} = \&ChainDelegateTool::parent_policy;
    $options->{require_policy} = 1;
    $options->{require_tool_scope} = 1;
    $options->{events} = $events;

    my $agent = Praxo::Agent::Agent->new($options);
    my $result = $agent->run(
        Praxo::Models::session(id => 'chain-parent'),
        'record parent, then delegate',
    );

    my $denied_model = ChainScriptedModel->new(
        steps => [
            {
                tool_calls => [
                    tool_call(
                        id => 'denied-record',
                        name => 'record',
                        arguments => { target => 'edit-me' },
                    ),
                ],
            },
        ],
        final => 'DONE',
    );
    my $denied_options = Praxo::Agent::AgentOptions->new($denied_model);
    $denied_options->{tools} = $registry;
    $denied_options->{max_steps} = 2;
    $denied_options->{allowed_tools} = ['record', 'delegate'];
    $denied_options->{policy} = \&ChainDelegateTool::parent_policy;
    $denied_options->{require_policy} = 1;
    $denied_options->{require_tool_scope} = 1;
    $denied_options->{events} = $events;
    $denied_options->{interrupt_on} = ['record'];
    $denied_options->{on_interrupt_decision} = sub {
        return Praxo::Models::interrupt_decision(
            action => 'edit',
            arguments => { target => 'blocked' },
        );
    };
    my $denied_agent = Praxo::Agent::Agent->new($denied_options);
    my $denied_error;
    eval {
        $denied_agent->run(
            Praxo::Models::session(id => 'chain-denied'),
            'attempt a denied edit',
        );
        1;
    } or $denied_error = $@;

    $client->close;
    return {
        output => $result->{output},
        effects => \%effects,
        child_calls => $child_model->calls,
        otel_spans => scalar @otel_log,
        harmovela_events => scalar @harmovela_log,
        denied_error => $denied_error,
        denied_effects => $effects{blocked} // 0,
    };
}

my $result = run_chain();
print 'output: ', $result->{output}, "\n";
print 'effects: parent=', ($result->{effects}{parent} // 0),
    ' child=', ($result->{effects}{child} // 0), "\n";
print 'child calls: ', $result->{child_calls}, "\n";
print 'otel spans: ', $result->{otel_spans}, "\n";
print 'harmovela events: ', $result->{harmovela_events}, "\n";
print 'denied effects: ', $result->{denied_effects}, "\n";
die "representative chain failed\n"
    unless $result->{output} eq 'DONE'
        && ($result->{effects}{parent} // 0) == 1
        && ($result->{effects}{child} // 0) == 1
        && $result->{child_calls} == 2
        && $result->{otel_spans} >= 3
        && $result->{harmovela_events} >= 3
        && $result->{denied_effects} == 0
        && defined $result->{denied_error};
