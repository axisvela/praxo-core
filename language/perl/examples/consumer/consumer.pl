use strict;
use warnings;
use lib 'language/perl/lib';
use Praxo::Agent ();
use Praxo::Models ();
use Praxo::Errors qw(error_code);

package FixtureModel;

sub new {
    my ($class, $target) = @_;
    return bless { target => $target }, $class;
}

sub generate {
    my ($self, $request) = @_;
    my $last = $request->{messages}->[-1];
    if (($last->{role} // '') eq Praxo::Models::TOOL()) {
        return Praxo::Models::response(
            message => Praxo::Models::message_assistant('recorded'),
        );
    }
    return Praxo::Models::response(
        message => Praxo::Models::message_assistant('', [
            Praxo::Models::tool_call(
                id => 'record-1',
                name => 'record',
                arguments => { target => $self->{target} },
            ),
        ]),
    );
}

package RecordTool;

sub new {
    my ($class) = @_;
    return bless { calls => 0 }, $class;
}

sub name { return 'record' }
sub description { return 'Record a target in an in-memory counter.' }

sub invoke {
    my ($self, $arguments) = @_;
    $self->{calls} += 1;
    return 'recorded';
}

package main;

sub authorize {
    my ($action) = @_;
    if ($action->{kind} eq 'model.generate') {
        return Praxo::Models::decision(allowed => 1);
    }
    if ($action->{kind} eq 'tool.invoke') {
        my $target = $action->{arguments}{target} // '';
        return Praxo::Models::decision(
            allowed => ($action->{toolName} // '') eq 'record' && $target eq 'public',
            reason => 'only the public target is permitted',
        );
    }
    return Praxo::Models::decision(allowed => 0, reason => 'unsupported action');
}

sub run_scenario {
    my ($target) = @_;
    my $tool = RecordTool->new;
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($tool);
    my $options = Praxo::Agent::AgentOptions->new(FixtureModel->new($target));
    $options->{tools} = $registry;
    $options->{max_steps} = 3;
    $options->{allowed_tools} = ['record'];
    $options->{policy} = \&authorize;
    my $result = eval {
        Praxo::Agent::run_agent(
            $options, Praxo::Models::session(id => "consumer-$target"),
            'Record the requested target.',
        );
    };
    return ($result, $tool->{calls}, $@);
}

my ($allowed, $allowed_effects, $allowed_error) = run_scenario('public');
if ($allowed_error
    || !$allowed
    || $allowed->{output} ne 'recorded'
    || $allowed_effects != 1) {
    die 'allow verification failed: output='
        . ($allowed ? $allowed->{output} : '')
        . " effects=$allowed_effects error=$allowed_error\n";
}
print "allow: recorded; effects=1\n";

my (undef, $denied_effects, $denied_error) = run_scenario('private');
my $code = error_code($denied_error);
if ($code ne 'POLICY_ERROR' || $denied_effects != 0) {
    die "deny verification failed: effects=$denied_effects error=$denied_error\n";
}
print "deny: policy rejected; effects=0\n";
