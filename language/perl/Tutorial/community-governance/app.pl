use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Praxo::Agent ();
use Praxo::Errors qw(error_code);
use Praxo::Json qw(parse stringify);
use Praxo::Models ();

package ReadIssuesTool;
sub new { return bless { calls => 0, failure => $_[1] ? 1 : 0 }, $_[0] }
sub name { return 'read_issues' }
sub description { return 'Classify fixed synthetic issues; no GitHub API.' }
sub invoke {
    my ($self, $args) = @_;
    $self->{calls}++;
    die "repo outside fixture\n" unless ($args->{repo} // '') eq 'repo-100';
    die "simulated issue index unavailable\n" if $self->{failure};
    return { repo => 'repo-100', issues => 4,
             categories => { bug => 2, docs => 1, question => 1 },
             unlabeled => 1, source => 'issue_fixture' };
}

package DraftGuidanceTool;
sub new { return bless { calls => 0 }, $_[0] }
sub name { return 'draft_guidance' }
sub description { return 'Draft review-only reviewer guidance; no closures or impersonation.' }
sub invoke {
    my ($self, $args) = @_;
    $self->{calls}++;
    return { guidance_id => 'guidance-100', repo => $args->{repo},
             action => $args->{action}, requests => 1, status => 'draft_only',
             review_required => 1, closures => 0, impersonations => 0 };
}

package FixtureModel;
sub new { return bless { repo => $_[1] }, $_[0] }
sub generate {
    my ($self, $request) = @_;
    my @tools = grep { ($_->{role} // '') eq Praxo::Models::TOOL() } @{$request->{messages}};
    if (!@tools) {
        return Praxo::Models::response(message => Praxo::Models::message_assistant('', [
            Praxo::Models::tool_call(id => 'issues-1', name => 'read_issues',
                                     arguments => { repo => $self->{repo} }),
        ]));
    }
    if (@tools == 1) {
        return Praxo::Models::response(message => Praxo::Models::message_assistant('', [
            Praxo::Models::tool_call(id => 'guidance-1', name => 'draft_guidance',
                                     arguments => { repo => $self->{repo}, action => 'draft_reviewer_request' }),
        ]));
    }
    return Praxo::Models::response(message => Praxo::Models::message_assistant(
        Praxo::Json::stringify({ stage => 'governance_drafted',
                                 issues => Praxo::Json::parse($tools[0]{content}),
                                 guidance => Praxo::Json::parse($tools[-1]{content}),
                                 closures => 0, impersonations => 0 })));
}

package main;
sub authorize {
    my ($action) = @_;
    return Praxo::Models::decision(allowed => 1) if $action->{kind} eq 'model.generate';
    return Praxo::Models::decision(allowed => 0) if $action->{kind} ne 'tool.invoke';
    my $name = $action->{toolName} // '';
    my $repo = $action->{arguments}{repo} // '';
    my $allowed = $repo eq 'repo-100';
    $allowed = 0 if $name eq 'draft_guidance'
        && ($action->{arguments}{action} // '') ne 'draft_reviewer_request';
    return Praxo::Models::decision(allowed => ($name eq 'read_issues' || $name eq 'draft_guidance') && $allowed,
                                   reason => 'only repo-100 reviewer request is allowed');
}

sub run_case {
    my ($repo, $failure) = @_;
    my $read = ReadIssuesTool->new($failure);
    my $draft = DraftGuidanceTool->new;
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($read);
    $registry->register($draft);
    my $options = Praxo::Agent::AgentOptions->new(FixtureModel->new($repo));
    $options->{tools} = $registry;
    $options->{max_steps} = 4;
    $options->{allowed_tools} = ['read_issues', 'draft_guidance'];
    $options->{policy} = \&authorize;
    my $result = eval {
        Praxo::Agent::run_agent($options, Praxo::Models::session(id => 'community-governance'),
            'Classify fixed issues and draft review-only reviewer guidance.');
    };
    return ($result, $read->{calls}, $draft->{calls}, $@);
}

sub run_tests {
    my ($success, $reads, $drafts, $error) = run_case('repo-100', 0);
    die "success failed: $error\n" if $error || !$success;
    die "success counts\n" unless $reads == 1 && $drafts == 1;
    my $report = parse($success->{output});
    die "issue count\n" unless $report->{issues}{issues} == 4;
    die "unlabeled count\n" unless $report->{issues}{unlabeled} == 1;
    die "not draft-only\n" unless $report->{guidance}{status} eq 'draft_only';
    die "request missing\n" unless $report->{guidance}{requests} == 1;
    die "unintended closure\n" unless $report->{closures} == 0 && $report->{impersonations} == 0;

    my (undef, $deny_reads, $deny_drafts, $deny_error) = run_case('repo-200', 0);
    die "denial failed\n" unless $deny_error && error_code($deny_error) eq 'POLICY_ERROR'
        && $deny_reads == 0 && $deny_drafts == 0;

    my (undef, $fail_reads, $fail_drafts, $fail_error) = run_case('repo-100', 1);
    die "failure failed\n" unless $fail_error && $fail_reads == 1 && $fail_drafts == 0;

    print "perl community-governance tutorial: all checks passed\n";
}

my $test = grep { $_ eq '--test' } @ARGV;
my $failure = grep { $_ eq '--simulate-failure' } @ARGV;
my $repo = 'repo-100';
for (my $i = 0; $i < @ARGV; $i++) {
    $repo = $ARGV[$i + 1] if $ARGV[$i] eq '--repo' && $i + 1 < @ARGV;
}
if ($test) { run_tests(); exit 0; }
my ($output, $reads, $drafts, $error) = run_case($repo, $failure);
if ($error) { warn "community governance failed: reads=$reads drafts=$drafts; $error\n"; exit 1; }
print $output->{output}, "\n";
