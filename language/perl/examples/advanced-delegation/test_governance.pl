use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Praxo::Agent ();
use Praxo::Models ();
use Praxo::Adapters::Delegation ();

package GovTool;

sub new {
    my ($class, %args) = @_;
    return bless {
        name => $args{name},
        effects => $args{effects},
    }, $class;
}

sub name { $_[0]->{name} }
sub description { 'Application-level effect tool' }
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

package GovModel;

sub new {
    my ($class, %args) = @_;
    return bless {
        steps => [ @{ $args{steps} // [] } ],
        final => $args{final} // 'done',
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

package main;

sub allow { Praxo::Models::decision(allowed => 1) }
sub deny { Praxo::Models::decision(allowed => 0, reason => $_[0] // 'denied') }

sub permissive_record {
    my ($action) = @_;
    return allow() if ($action->{kind} // '') eq 'model.generate';
    return allow() if ($action->{kind} // '') eq 'tool.invoke'
        && ($action->{toolName} // '') eq 'record';
    return deny('child may only record');
}

sub parent_deny_blocked {
    my ($action) = @_;
    return allow() if ($action->{kind} // '') eq 'model.generate';
    return deny('parent tool is not allowed')
        unless ($action->{kind} // '') eq 'tool.invoke'
            && ($action->{toolName} // '') eq 'record';
    return deny('blocked target')
        if (($action->{arguments} // {})->{target} // '') eq 'blocked';
    return allow();
}

sub composed_policy {
    my ($parent, $child) = @_;
    return sub {
        my ($action) = @_;
        my $decision = $parent->($action);
        return $decision unless $decision->{allowed};
        return $child->($action);
    };
}

sub tool_call {
    my (%args) = @_;
    return Praxo::Models::tool_call(
        id => $args{id},
        name => $args{name},
        arguments => $args{arguments},
    );
}

sub run_child {
    my (%args) = @_;
    my $effects = $args{effects};
    my $budget = $args{budget};
    my $children = $args{children};
    my $max_children = $args{max_children};
    my $depth = $args{depth} // 0;
    my $max_depth = $args{max_depth};

    return { status => 'cancelled', error => 'CANCELLED' } if $args{cancelled};
    return { status => 'denied', error => 'DEPTH_LIMIT' }
        if defined $max_depth && $depth > $max_depth;
    return { status => 'denied', error => 'CHILD_LIMIT' }
        if defined $max_children && defined $children && $$children >= $max_children;
    return { status => 'denied', error => 'BUDGET_EXHAUSTED' }
        if defined $budget && $$budget <= 0;
    $$children++ if defined $children;

    my $options = Praxo::Agent::AgentOptions->new($args{model});
    $options->{tools} = $args{tools};
    $options->{max_steps} = 3;
    $options->{allowed_tools} = $args{allowed_tools};
    $options->{policy} = $args{policy};
    $options->{require_policy} = 1;
    $options->{require_tool_scope} = 1;
    $options->{interrupt_on} = $args{interrupt_on} if $args{interrupt_on};
    $options->{on_interrupt_decision} = $args{on_interrupt} if $args{on_interrupt};

    my $result = Praxo::Adapters::Delegation::subagent_run(
        sub {
            my $agent = Praxo::Agent::Agent->new($options);
            my $run = $agent->run(
                Praxo::Models::session(id => 'governance-child'),
                'run child',
            );
            return { output => $run->{output} };
        },
        {
            parentSessionId => 'governance-parent',
            agentId => 'governance-child',
            mode => 'isolated',
        },
    );
    $$budget-- if defined $budget && $result->{status} eq 'completed';
    return $result;
}

sub registry {
    my ($effects) = @_;
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register(GovTool->new(name => 'record', effects => $effects));
    $registry->register(GovTool->new(name => 'write', effects => $effects));
    return $registry;
}

sub model_for {
    my ($tool, $target) = @_;
    return GovModel->new(
        steps => [
            {
                tool_calls => [
                    tool_call(
                        id => 'call-1',
                        name => $tool,
                        arguments => { target => $target },
                    ),
                ],
            },
        ],
    );
}

sub assert_true {
    my ($condition, $message) = @_;
    die "assertion failed: $message\n" unless $condition;
}

# 1. Child scope narrowing: write is not in the allowed scope.
{
    my %effects;
    my $result = run_child(
        effects => \%effects,
        model => model_for('write', 'escape'),
        tools => registry(\%effects),
        allowed_tools => ['record'],
        policy => \&permissive_record,
    );
    assert_true($result->{status} eq 'failed', 'scope narrowing fails');
    assert_true(($effects{escape} // 0) == 0, 'scope narrowing has no effect');
}

# 2. Parent policy composition: parent denial wins over child allow.
{
    my %effects;
    my $result = run_child(
        effects => \%effects,
        model => model_for('record', 'blocked'),
        tools => registry(\%effects),
        allowed_tools => ['record'],
        policy => composed_policy(\&parent_deny_blocked, \&permissive_record),
    );
    assert_true($result->{status} eq 'failed', 'policy composition denies');
    assert_true(($effects{blocked} // 0) == 0, 'policy composition has no effect');
}

# 3. Shared sibling budget: the second child cannot spend the same unit.
{
    my %effects;
    my $budget = 1;
    my $first = run_child(
        effects => \%effects,
        model => model_for('record', 'sibling'),
        tools => registry(\%effects),
        allowed_tools => ['record'],
        policy => \&permissive_record,
        budget => \$budget,
    );
    my $second = run_child(
        effects => \%effects,
        model => model_for('record', 'sibling'),
        tools => registry(\%effects),
        allowed_tools => ['record'],
        policy => \&permissive_record,
        budget => \$budget,
    );
    assert_true($first->{status} eq 'completed', 'first sibling completes');
    assert_true($second->{status} eq 'denied', 'second sibling is denied');
    assert_true($second->{error} eq 'BUDGET_EXHAUSTED', 'second sibling budget error');
    assert_true(($effects{sibling} // 0) == 1, 'sibling budget is not exceeded');
}

# 4. Child-count and depth limits reject before execution.
{
    my %effects;
    my $children = 0;
    my $first = run_child(
        effects => \%effects,
        model => model_for('record', 'limit'),
        tools => registry(\%effects),
        allowed_tools => ['record'],
        policy => \&permissive_record,
        children => \$children,
        max_children => 1,
    );
    my $second = run_child(
        effects => \%effects,
        model => model_for('record', 'limit'),
        tools => registry(\%effects),
        allowed_tools => ['record'],
        policy => \&permissive_record,
        children => \$children,
        max_children => 1,
    );
    my $deep = run_child(
        effects => \%effects,
        model => model_for('record', 'limit'),
        tools => registry(\%effects),
        allowed_tools => ['record'],
        policy => \&permissive_record,
        depth => 2,
        max_depth => 1,
    );
    assert_true($first->{status} eq 'completed', 'first child completes');
    assert_true($second->{error} eq 'CHILD_LIMIT', 'child limit rejects');
    assert_true($deep->{error} eq 'DEPTH_LIMIT', 'depth limit rejects');
    assert_true(($effects{limit} // 0) == 1, 'limit checks have no extra effect');
}

# 5. Cancellation before execution leaves no effect.
{
    my %effects;
    my $result = run_child(
        effects => \%effects,
        model => model_for('record', 'cancel'),
        tools => registry(\%effects),
        allowed_tools => ['record'],
        policy => \&permissive_record,
        cancelled => 1,
    );
    assert_true($result->{status} eq 'cancelled', 'cancellation short-circuits');
    assert_true(($effects{cancel} // 0) == 0, 'cancellation has no effect');
}

# 6. Final-argument reauthorization: an approval edit to blocked is denied.
{
    my %effects;
    my $result = run_child(
        effects => \%effects,
        model => model_for('record', 'edit-me'),
        tools => registry(\%effects),
        allowed_tools => ['record'],
        policy => \&parent_deny_blocked,
        interrupt_on => ['record'],
        on_interrupt => sub {
            return Praxo::Models::interrupt_decision(
                action => 'edit',
                arguments => { target => 'blocked' },
            );
        },
    );
    assert_true($result->{status} eq 'failed', 'edited call is denied');
    assert_true(($effects{'edit-me'} // 0) == 0, 'original edit target has no effect');
    assert_true(($effects{blocked} // 0) == 0, 'edited target has no effect');
}

print "Perl advanced delegation governance: 6/6 passed\n";
