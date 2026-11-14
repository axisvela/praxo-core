use strict;
use warnings;
use lib 'language/perl/lib';
use Praxo::Models;
use Praxo::Runtime;

package RecordingSink;

sub new {
    my ($class) = @_;
    return bless { types => [] }, $class;
}

sub emit {
    my ($self, $event) = @_;
    push @{ $self->{types} }, $event->{type};
}

sub types {
    my ($self) = @_;
    return $self->{types};
}

package main;

my $all = RecordingSink->new;
my $tool = RecordingSink->new;
my $filter = Praxo::Runtime::FilterSink->new($tool, sub {
    return $_[0]{type} eq 'tool.call';
});
my $multi = Praxo::Runtime::MultiSink->new([$all, $filter]);
for my $type (qw(run.started tool.call run.completed)) {
    $multi->emit(Praxo::Models::event(type => $type, session_id => 's1'));
}

die "unexpected event delivery\n"
    unless join(',', @{ $all->types }) eq 'run.started,tool.call,run.completed'
        && join(',', @{ $tool->types }) eq 'tool.call';

print "Perl event sink example passed\n";
