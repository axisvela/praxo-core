use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use Praxo::Agent ();
use Praxo::Errors qw(error_code);
use Praxo::Json qw(parse stringify);
use Praxo::Models ();

package LogSummaryTool;

sub new {
    my ($class, $fixture, $simulate_failure) = @_;
    return bless {
        fixture => $fixture,
        simulate_failure => $simulate_failure ? 1 : 0,
        calls => 0,
    }, $class;
}

sub name { return 'summarize_log' }
sub description { return 'Count severity levels in the fixed tutorial log; no writes or arbitrary paths.' }

sub invoke {
    my ($self, $arguments) = @_;
    $self->{calls} += 1;
    die "unknown log fixture\n" unless ($arguments->{name} // '') eq 'fixture';
    die "simulated log dependency unavailable\n" if $self->{simulate_failure};

    open my $handle, '<', $self->{fixture} or die "cannot read fixture log: $!\n";
    my %counts = (ERROR => 0, WARN => 0, INFO => 0);
    my $first_error;
    while (my $line = <$handle>) {
        chomp $line;
        next unless $line =~ /\b(ERROR|WARN|INFO)\b/;
        $counts{$1}++;
        $first_error //= $line if $1 eq 'ERROR';
    }
    close $handle;
    return {
        source => 'fixture',
        errors => $counts{ERROR},
        warnings => $counts{WARN},
        info => $counts{INFO},
        first_error => $first_error,
    };
}

package FixtureModel;

sub new {
    my ($class, $log_name) = @_;
    return bless { log_name => $log_name }, $class;
}

sub generate {
    my ($self, $request) = @_;
    my @tool_messages = grep { ($_->{role} // '') eq Praxo::Models::TOOL() } @{$request->{messages}};
    if (@tool_messages) {
        my $summary = Praxo::Json::parse($tool_messages[-1]{content});
        return Praxo::Models::response(
            message => Praxo::Models::message_assistant(
                Praxo::Json::stringify({ log => $summary, mutating_actions => [] }),
            ),
        );
    }
    return Praxo::Models::response(
        message => Praxo::Models::message_assistant('', [
            Praxo::Models::tool_call(
                id => 'log-1',
                name => 'summarize_log',
                arguments => { name => $self->{log_name} },
            ),
        ]),
    );
}

package main;

sub authorize {
    my ($action) = @_;
    if ($action->{kind} eq 'model.generate') {
        return Praxo::Models::decision(allowed => 1);
    }
    if ($action->{kind} eq 'tool.invoke') {
        my $name = $action->{arguments}{name} // '';
        return Praxo::Models::decision(
            allowed => ($action->{toolName} // '') eq 'summarize_log' && $name eq 'fixture',
            reason => 'only the fixed fixture log is readable',
        );
    }
    return Praxo::Models::decision(allowed => 0, reason => 'unsupported action');
}

sub run_triage {
    my ($log_name, $simulate_failure) = @_;
    my $tool = LogSummaryTool->new("$FindBin::Bin/fixture.log", $simulate_failure);
    my $registry = Praxo::Agent::ToolRegistry->new;
    $registry->register($tool);
    my $options = Praxo::Agent::AgentOptions->new(FixtureModel->new($log_name));
    $options->{tools} = $registry;
    $options->{max_steps} = 3;
    $options->{allowed_tools} = ['summarize_log'];
    $options->{policy} = \&authorize;
    my $result = eval {
        Praxo::Agent::run_agent(
            $options,
            Praxo::Models::session(id => 'log-triage'),
            'Inspect the fixed tutorial log and report counts only.',
        );
    };
    return ($result, $tool->{calls}, $@);
}

sub run_tests {
    my ($success, $success_calls, $success_error) = run_triage('fixture', 0);
    die "success run failed: $success_error\n" if $success_error || !$success;
    my $report = parse($success->{output});
    die "unexpected error count\n" unless $report->{log}{errors} == 2;
    die "unexpected warning count\n" unless $report->{log}{warnings} == 1;
    die "unexpected info count\n" unless $report->{log}{info} == 2;
    die "unexpected success read count\n" unless $success_calls == 1;
    die "unexpected mutating action\n" unless ref($report->{mutating_actions}) eq 'ARRAY' && @{$report->{mutating_actions}} == 0;

    my (undef, $denied_calls, $denied_error) = run_triage('other', 0);
    die "denial did not fail\n" unless $denied_error;
    die "denial error was not a policy error: $denied_error\n" unless error_code($denied_error) eq 'POLICY_ERROR';
    die "denial performed a read\n" unless $denied_calls == 0;

    my (undef, $failed_calls, $failed_error) = run_triage('fixture', 1);
    die "dependency failure did not fail\n" unless $failed_error;
    die "dependency failure read count mismatch\n" unless $failed_calls == 1;

    print "perl log-triage tutorial: all checks passed\n";
}

my $test = grep { $_ eq '--test' } @ARGV;
my $simulate_failure = grep { $_ eq '--simulate-failure' } @ARGV;
my $log_name = 'fixture';
for (my $index = 0; $index < @ARGV; $index++) {
    if ($ARGV[$index] eq '--log' && $index + 1 < @ARGV) {
        $log_name = $ARGV[++$index];
    }
}
if ($test) {
    run_tests();
    exit 0;
}
my ($output, $calls, $error) = run_triage($log_name, $simulate_failure);
if ($error) {
    warn "log triage failed: reads=$calls; $error\n";
    exit 1;
}
print $output->{output}, "\n";
