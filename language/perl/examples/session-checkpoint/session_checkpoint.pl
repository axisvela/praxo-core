use strict;
use warnings;
use lib 'language/perl/lib';
use Praxo::Agent ();
use Praxo::Models ();
use Praxo::Runtime ();

package TurnModel;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub generate {
    my ($self, $request) = @_;
    my $count = scalar @{ $request->{messages} // [] };
    return Praxo::Models::response(
        message => Praxo::Models::message_assistant("turn $count"),
    );
}

package main;

my $model = TurnModel->new;
my $options = Praxo::Agent::AgentOptions->new($model);
$options->{max_steps} = 2;

my $session = Praxo::Models::session(
    id => 'session-1',
    messages => [
        Praxo::Models::message_text('user', 'first'),
        Praxo::Models::message_text('assistant', 'ack'),
    ],
);

my $result = Praxo::Agent::run_agent($options, $session, 'second');
die "unexpected second turn\n" unless $result->{output} eq 'turn 3';
push @{ $session->{messages} },
    Praxo::Models::message_text('user', 'second'),
    Praxo::Models::message_text('assistant', $result->{output});

my $allow = Praxo::Runtime::CheckpointAllowlist->new;
$allow->register('session');
my $payload = $allow->marshal('session', { messages => $session->{messages} });
my $restored = $allow->unmarshal($payload);
$session->{messages} = $restored->{messages};

$result = Praxo::Agent::run_agent($options, $session, 'third');
die "unexpected third turn\n" unless $result->{output} eq 'turn 5';

print "restored messages: " . scalar(@{ $session->{messages} }) . "\n";
print "output: $result->{output}\n";
