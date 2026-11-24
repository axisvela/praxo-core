use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Praxo::Agent ();
use Praxo::Errors qw(error_code);
use Praxo::Json qw(parse stringify);
use Praxo::Models ();

package ReadChangesTool;
sub new { return bless { calls => 0, failure => $_[1] ? 1 : 0 }, $_[0] }
sub name { return 'read_changes' }
sub description { return 'Compare fixed policy versions; no external source fetching.' }
sub invoke {
    my ($self, $args) = @_;
    $self->{calls}++;
    die "policy outside fixture\n" unless ($args->{policy} // '') eq 'policy-100';
    die "simulated policy source unavailable\n" if $self->{failure};
    return { policy => 'policy-100', from_version => 1, to_version => 2,
             changed_sections => ['retention', 'approval'], duplicates_removed => 1,
             source => 'policy_fixture' };
}

package DraftRemediationTool;
sub new { return bless { calls => 0 }, $_[0] }
sub name { return 'draft_remediation' }
sub description { return 'Draft review-only remediation findings; no filing or audit conclusion.' }
sub invoke {
    my ($self, $args) = @_;
    $self->{calls}++;
    return { remediation_id => 'compliance-100', policy => $args->{policy},
             action => $args->{action}, findings => 2, status => 'draft_only',
             review_required => 1, filings => 0, audit_conclusions => 0 };
}

package FixtureModel;
sub new { return bless { policy => $_[1] }, $_[0] }
sub generate {
    my ($self, $request) = @_;
    my @tools = grep { ($_->{role} // '') eq Praxo::Models::TOOL() } @{$request->{messages}};
    if (!@tools) {
        return Praxo::Models::response(message => Praxo::Models::message_assistant('', [
            Praxo::Models::tool_call(id => 'changes-1', name => 'read_changes',
                                     arguments => { policy => $self->{policy} }),
        ]));
    }
    if (@tools == 1) {
        return Praxo::Models::response(message => Praxo::Models::message_assistant('', [
            Praxo::Models::tool_call(id => 'remediation-1', name => 'draft_remediation',
                                     arguments => { policy => $self->{policy}, action => 'draft_finding' }),
        ]));
    }
    return Praxo::Models::response(message => Praxo::Models::message_assistant(
        Praxo::Json::stringify({ stage => 'compliance_review_drafted',
                                 changes => Praxo::Json::parse($tools[0]{content}),
                                 remediation => Praxo::Json::parse($tools[-1]{content}),
                                 filings => 0, audit_conclusions => 0 })));
}

package main;
sub authorize {
    my ($action) = @_;
    return Praxo::Models::decision(allowed => 1) if $action->{kind} eq 'model.generate';
    return Praxo::Models::decision(allowed => 0) if $action->{kind} ne 'tool.invoke';
    my $name = $action->{toolName} // '';
    my $policy = $action->{arguments}{policy} // '';
    my $allowed = $policy eq 'policy-100';
    $allowed = 0 if $name eq 'draft_remediation'
        && ($action->{arguments}{action} // '') ne 'draft_finding';
    return Praxo::Models::decision(allowed => ($name eq 'read_changes' || $name eq 'draft_remediation') && $allowed,
                                   reason => 'only policy-100 draft_finding is allowed');
}

sub run_case {
    my ($policy, $failure) = @_;
    my $read = ReadChangesTool->new($failure);
    my $draft = DraftRemediationTool->new;
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($read);
    $registry->register($draft);
    my $options = Praxo::Agent::AgentOptions->new(FixtureModel->new($policy));
    $options->{tools} = $registry;
    $options->{max_steps} = 4;
    $options->{allowed_tools} = ['read_changes', 'draft_remediation'];
    $options->{policy} = \&authorize;
    my $result = eval {
        Praxo::Agent::run_agent($options, Praxo::Models::session(id => 'compliance-tracking'),
            'Compare fixed policy versions and draft review-only remediation.');
    };
    return ($result, $read->{calls}, $draft->{calls}, $@);
}

sub run_tests {
    my ($success, $reads, $drafts, $error) = run_case('policy-100', 0);
    die "success failed: $error\n" if $error || !$success;
    die "success counts\n" unless $reads == 1 && $drafts == 1;
    my $report = parse($success->{output});
    die "changed sections\n" unless @{$report->{changes}{changed_sections}} == 2;
    die "duplicates\n" unless $report->{changes}{duplicates_removed} == 1;
    die "not draft-only\n" unless $report->{remediation}{status} eq 'draft_only';
    die "unintended filing\n" unless $report->{filings} == 0 && $report->{audit_conclusions} == 0;

    my (undef, $deny_reads, $deny_drafts, $deny_error) = run_case('policy-200', 0);
    die "denial failed\n" unless $deny_error && error_code($deny_error) eq 'POLICY_ERROR'
        && $deny_reads == 0 && $deny_drafts == 0;

    my (undef, $fail_reads, $fail_drafts, $fail_error) = run_case('policy-100', 1);
    die "failure failed\n" unless $fail_error && $fail_reads == 1 && $fail_drafts == 0;

    print "perl compliance-tracking tutorial: all checks passed\n";
}

my $test = grep { $_ eq '--test' } @ARGV;
my $failure = grep { $_ eq '--simulate-failure' } @ARGV;
my $policy = 'policy-100';
for (my $i = 0; $i < @ARGV; $i++) {
    $policy = $ARGV[$i + 1] if $ARGV[$i] eq '--policy' && $i + 1 < @ARGV;
}
if ($test) { run_tests(); exit 0; }
my ($output, $reads, $drafts, $error) = run_case($policy, $failure);
if ($error) { warn "compliance tracking failed: reads=$reads drafts=$drafts; $error\n"; exit 1; }
print $output->{output}, "\n";
