use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Praxo::Agent ();
use Praxo::Errors qw(error_code);
use Praxo::Json qw(parse stringify);
use Praxo::Models ();

package CompareSourcesTool;

sub new {
    my ($class, $simulate_failure) = @_;
    return bless { simulate_failure => $simulate_failure ? 1 : 0, calls => 0 }, $class;
}

sub name { return 'compare_sources' }
sub description { return 'Compare fixed source excerpts for one synthetic article; no live crawl.' }

sub invoke {
    my ($self, $arguments) = @_;
    $self->{calls} += 1;
    die "unknown article fixture\n" unless ($arguments->{article_id} // '') eq 'article-100';
    die "simulated source index unavailable\n" if $self->{simulate_failure};
    return {
        article_id => 'article-100',
        claims => [
            { claim => 'budget increase', support => 'source-1', contradiction => 'source-2' },
            { claim => 'timeline unchanged', support => 'source-1', contradiction => undef },
        ],
        sources => 2,
        confidence => 'uncertain',
        source => 'source_fixture',
    };
}

package DraftFactcheckTool;

sub new { return bless { calls => 0 }, shift }

sub name { return 'draft_factcheck' }
sub description { return 'Draft a review-only fact-check; never publishes a truth verdict.' }

sub invoke {
    my ($self, $arguments) = @_;
    $self->{calls} += 1;
    return {
        factcheck_id => 'factcheck-100',
        article_id => $arguments->{article_id},
        action => $arguments->{action},
        status => 'draft_only',
        review_required => 1,
        truth_verdicts => 0,
        publishes => 0,
    };
}

package FixtureModel;

sub new { return bless { article => $_[1] }, $_[0] }

sub generate {
    my ($self, $request) = @_;
    my @tool_messages = grep { ($_->{role} // '') eq Praxo::Models::TOOL() } @{$request->{messages}};
    if (!@tool_messages) {
        return Praxo::Models::response(
            message => Praxo::Models::message_assistant('', [
                Praxo::Models::tool_call(
                    id => 'compare-1',
                    name => 'compare_sources',
                    arguments => { article_id => $self->{article} },
                ),
            ]),
        );
    }
    if (@tool_messages == 1) {
        return Praxo::Models::response(
            message => Praxo::Models::message_assistant('', [
                Praxo::Models::tool_call(
                    id => 'factcheck-1',
                    name => 'draft_factcheck',
                    arguments => { article_id => $self->{article}, action => 'draft_review' },
                ),
            ]),
        );
    }
    my $article = Praxo::Json::parse($tool_messages[0]{content});
    my $factcheck = Praxo::Json::parse($tool_messages[-1]{content});
    return Praxo::Models::response(
        message => Praxo::Models::message_assistant(
            Praxo::Json::stringify({
                article => $article,
                factcheck => $factcheck,
                truth_verdicts => 0,
                publishes => 0,
            }),
        ),
    );
}

package main;

sub authorize {
    my ($action) = @_;
    if ($action->{kind} eq 'model.generate') {
        return Praxo::Models::decision(allowed => 1);
    }
    if ($action->{kind} eq 'tool.invoke') {
        my $article = $action->{arguments}{article_id} // '';
        my $name = $action->{toolName} // '';
        my $allowed = $article eq 'article-100';
        $allowed = 0 if $name eq 'draft_factcheck'
            && ($action->{arguments}{action} // '') ne 'draft_review';
        return Praxo::Models::decision(
            allowed => ($name eq 'compare_sources' || $name eq 'draft_factcheck') && $allowed,
            reason => 'only article-100 draft_review is allowed',
        );
    }
    return Praxo::Models::decision(allowed => 0, reason => 'unsupported action');
}

sub run_factcheck {
    my ($article, $simulate_failure) = @_;
    my $compare = CompareSourcesTool->new($simulate_failure);
    my $draft = DraftFactcheckTool->new;
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($compare);
    $registry->register($draft);
    my $options = Praxo::Agent::AgentOptions->new(FixtureModel->new($article));
    $options->{tools} = $registry;
    $options->{max_steps} = 4;
    $options->{allowed_tools} = ['compare_sources', 'draft_factcheck'];
    $options->{policy} = \&authorize;
    my $result = eval {
        Praxo::Agent::run_agent(
            $options,
            Praxo::Models::session(id => 'news-factcheck'),
            'Compare the fixed sources and draft a review-only fact-check.',
        );
    };
    return ($result, $compare->{calls}, $draft->{calls}, $@);
}

sub run_tests {
    my ($success, $reads, $drafts, $error) = run_factcheck('article-100', 0);
    die "success run failed: $error\n" if $error || !$success;
    die "unexpected success counts\n" unless $reads == 1 && $drafts == 1;
    my $report = parse($success->{output});
    die "unexpected claim count\n" unless @{$report->{article}{claims}} == 2;
    die "expected a contradiction\n" unless $report->{article}{claims}[0]{contradiction} eq 'source-2';
    die "not draft-only\n" unless $report->{factcheck}{status} eq 'draft_only';
    die "unintended truth verdict\n" unless $report->{truth_verdicts} == 0
        && $report->{factcheck}{truth_verdicts} == 0;
    die "unintended publish\n" unless $report->{publishes} == 0;

    my (undef, $denied_reads, $denied_drafts, $denied_error) = run_factcheck('article-200', 0);
    die "denial did not fail\n" unless $denied_error;
    die "denial error was not a policy error: $denied_error\n" unless error_code($denied_error) eq 'POLICY_ERROR';
    die "denial performed a read\n" unless $denied_reads == 0 && $denied_drafts == 0;

    my (undef, $failed_reads, $failed_drafts, $failed_error) = run_factcheck('article-100', 1);
    die "dependency failure did not fail\n" unless $failed_error;
    die "dependency failure counts mismatch\n" unless $failed_reads == 1 && $failed_drafts == 0;

    print "perl news-factcheck tutorial: all checks passed\n";
}

my $test = grep { $_ eq '--test' } @ARGV;
my $simulate_failure = grep { $_ eq '--simulate-failure' } @ARGV;
my $article = 'article-100';
for (my $index = 0; $index < @ARGV; $index++) {
    if ($ARGV[$index] eq '--article' && $index + 1 < @ARGV) {
        $article = $ARGV[++$index];
    }
}
if ($test) {
    run_tests();
    exit 0;
}
my ($output, $reads, $drafts, $error) = run_factcheck($article, $simulate_failure);
if ($error) {
    warn "news fact-check failed: reads=$reads drafts=$drafts; $error\n";
    exit 1;
}
print $output->{output}, "\n";
