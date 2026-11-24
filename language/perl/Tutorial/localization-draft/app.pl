use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Praxo::Agent ();
use Praxo::Errors qw(error_code);
use Praxo::Json qw(parse stringify);
use Praxo::Models ();

package ReadTermsTool;
sub new { return bless { calls => 0, failure => $_[1] ? 1 : 0 }, $_[0] }
sub name { return 'read_terms' }
sub description { return 'Read fixed localization rules; no translation engine.' }
sub invoke {
    my ($self, $args) = @_;
    $self->{calls}++;
    die "product outside fixture\n" unless ($args->{product} // '') eq 'product-100';
    die "simulated terms unavailable\n" if $self->{failure};
    return { product => 'product-100', markets => ['de'],
             rules => ['formal-address', 'unit-cm'], source => 'terms_fixture' };
}

package DraftLocalizationTool;
sub new { return bless { calls => 0 }, $_[0] }
sub name { return 'draft_localization' }
sub description { return 'Draft review-only localized text; no legal or tax guarantee.' }
sub invoke {
    my ($self, $args) = @_;
    $self->{calls}++;
    return { draft_id => 'localization-100', product => $args->{product},
             action => $args->{action}, segments => 2, status => 'draft_only',
             review_required => 1, legal_guarantees => 0, tax_claims => 0 };
}

package FixtureModel;
sub new { return bless { product => $_[1] }, $_[0] }
sub generate {
    my ($self, $request) = @_;
    my @tools = grep { ($_->{role} // '') eq Praxo::Models::TOOL() } @{$request->{messages}};
    if (!@tools) {
        return Praxo::Models::response(message => Praxo::Models::message_assistant('', [
            Praxo::Models::tool_call(id => 'terms-1', name => 'read_terms',
                                     arguments => { product => $self->{product} }),
        ]));
    }
    if (@tools == 1) {
        return Praxo::Models::response(message => Praxo::Models::message_assistant('', [
            Praxo::Models::tool_call(id => 'draft-1', name => 'draft_localization',
                                     arguments => { product => $self->{product}, action => 'draft_localized' }),
        ]));
    }
    return Praxo::Models::response(message => Praxo::Models::message_assistant(
        Praxo::Json::stringify({ terms => Praxo::Json::parse($tools[0]{content}),
                                 draft => Praxo::Json::parse($tools[-1]{content}),
                                 legal_guarantees => 0, tax_claims => 0 })));
}

package main;
sub authorize {
    my ($action) = @_;
    return Praxo::Models::decision(allowed => 1) if $action->{kind} eq 'model.generate';
    return Praxo::Models::decision(allowed => 0) if $action->{kind} ne 'tool.invoke';
    my $name = $action->{toolName} // '';
    my $product = $action->{arguments}{product} // '';
    my $allowed = $product eq 'product-100';
    $allowed = 0 if $name eq 'draft_localization'
        && ($action->{arguments}{action} // '') ne 'draft_localized';
    return Praxo::Models::decision(allowed => ($name eq 'read_terms' || $name eq 'draft_localization') && $allowed,
                                   reason => 'only product-100 draft_localized is allowed');
}

sub run_case {
    my ($product, $failure) = @_;
    my $read = ReadTermsTool->new($failure);
    my $draft = DraftLocalizationTool->new;
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($read);
    $registry->register($draft);
    my $options = Praxo::Agent::AgentOptions->new(FixtureModel->new($product));
    $options->{tools} = $registry;
    $options->{max_steps} = 4;
    $options->{allowed_tools} = ['read_terms', 'draft_localization'];
    $options->{policy} = \&authorize;
    my $result = eval {
        Praxo::Agent::run_agent($options, Praxo::Models::session(id => 'localization-draft'),
            'Compare fixed rules and draft review-only localized text.');
    };
    return ($result, $read->{calls}, $draft->{calls}, $@);
}

sub run_tests {
    my ($success, $reads, $drafts, $error) = run_case('product-100', 0);
    die "success failed: $error\n" if $error || !$success;
    die "success counts\n" unless $reads == 1 && $drafts == 1;
    my $report = parse($success->{output});
    die "rules missing\n" unless $report->{terms}{markets}[0] eq 'de';
    die "not draft-only\n" unless $report->{draft}{status} eq 'draft_only';
    die "unintended guarantee\n" unless $report->{legal_guarantees} == 0 && $report->{tax_claims} == 0;

    my (undef, $deny_reads, $deny_drafts, $deny_error) = run_case('product-200', 0);
    die "denial failed\n" unless $deny_error && error_code($deny_error) eq 'POLICY_ERROR'
        && $deny_reads == 0 && $deny_drafts == 0;

    my (undef, $fail_reads, $fail_drafts, $fail_error) = run_case('product-100', 1);
    die "failure failed\n" unless $fail_error && $fail_reads == 1 && $fail_drafts == 0;

    print "perl localization-draft tutorial: all checks passed\n";
}

my $test = grep { $_ eq '--test' } @ARGV;
my $failure = grep { $_ eq '--simulate-failure' } @ARGV;
my $product = 'product-100';
for (my $i = 0; $i < @ARGV; $i++) {
    $product = $ARGV[$i + 1] if $ARGV[$i] eq '--product' && $i + 1 < @ARGV;
}
if ($test) { run_tests(); exit 0; }
my ($output, $reads, $drafts, $error) = run_case($product, $failure);
if ($error) { warn "localization failed: reads=$reads drafts=$drafts; $error\n"; exit 1; }
print $output->{output}, "\n";
