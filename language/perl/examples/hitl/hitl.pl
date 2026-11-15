use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Praxo::Agent ();
use Praxo::Models ();
use Praxo::Errors qw(error_code);

package FixtureModel;

sub new { bless {}, shift }

sub generate {
    my ($self, $request) = @_;
    my $last = $request->{messages}[-1];
    if (($last->{role} // '') eq Praxo::Models::TOOL()) {
        return Praxo::Models::response(
            message => Praxo::Models::message_assistant('done'),
        );
    }
    return Praxo::Models::response(
        message => Praxo::Models::message_assistant('', [
            Praxo::Models::tool_call(
                id => 'write-note-1',
                name => 'write_note',
                arguments => { text => 'hello', visibility => 'public' },
            ),
        ]),
    );
}

package WriteNoteTool;

sub new { bless { notes => [] }, shift }

sub name { 'write_note' }
sub description { 'Write a short note with the requested visibility.' }
sub risk { 'write' }

sub parameters {
    return {
        type => 'object',
        required => ['text', 'visibility'],
        properties => {
            text => { type => 'string' },
            visibility => { type => 'string', enum => ['public', 'private'] },
        },
    };
}

sub invoke {
    my ($self, $arguments) = @_;
    push @{ $self->{notes} }, $arguments->{text};
    return 'written';
}

package main;

sub allow_public {
    my ($action) = @_;
    if ($action->{kind} eq 'model.generate') {
        return Praxo::Models::decision(allowed => 1);
    }
    if ($action->{kind} eq 'tool.invoke') {
        return Praxo::Models::decision(
            allowed => ($action->{toolName} // '') eq 'write_note'
                && ($action->{arguments}{visibility} // '') eq 'public',
            reason => 'only public notes are permitted',
        );
    }
    return Praxo::Models::decision(allowed => 0, reason => 'unsupported action');
}

sub build_agent {
    my ($decision) = @_;
    my $tool = WriteNoteTool->new;
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($tool);
    my $options = Praxo::Agent::AgentOptions->new(FixtureModel->new);
    $options->{tools} = $registry;
    $options->{max_steps} = 3;
    $options->{allowed_tools} = ['write_note'];
    $options->{policy} = \&allow_public;
    $options->{interrupt_on} = ['write_note'];
    $options->{on_interrupt_decision} = sub { $decision };
    return ($options, $tool);
}

sub run {
    my ($output) = @_;
    $output //= \*STDOUT;

    my ($approve_options, $approve_tool) = build_agent(
        Praxo::Models::interrupt_decision(
            action => Praxo::Models::INTERRUPT_APPROVE(),
        ),
    );
    my $result = Praxo::Agent::run_agent(
        $approve_options, Praxo::Models::session(id => 'hitl-approve'),
        'Write a note.',
    );
    die 'approve scenario failed: output='
        . ($result->{output} // '')
        . ' effects=' . scalar(@{ $approve_tool->{notes} }) . "\n"
        unless $result->{output} eq 'done'
            && @{ $approve_tool->{notes} } == 1;
    print {$output} "approve: written; effects=1\n";

    my ($edit_options, $edit_tool) = build_agent(
        Praxo::Models::interrupt_decision(
            action => Praxo::Models::INTERRUPT_EDIT(),
            arguments => { text => 'hello', visibility => 'private' },
        ),
    );
    my $ok = eval {
        Praxo::Agent::run_agent(
            $edit_options, Praxo::Models::session(id => 'hitl-edit'),
            'Write a note.',
        );
        1;
    };
    my $error = $@;
    die "edited private note was not denied\n" if $ok;
    die 'edit scenario failed: error=' . error_code($error) . "\n"
        unless error_code($error) eq 'POLICY_ERROR';
    die 'edit produced effects=' . scalar(@{ $edit_tool->{notes} }) . "\n"
        unless @{ $edit_tool->{notes} } == 0;
    print {$output} "edit: policy rejected; effects=0\n";
}

run() unless caller;

1;
