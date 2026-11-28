use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Praxo::Core',
    DISTNAME         => 'Praxo-Core',
    VERSION          => '0.8.1',
    ABSTRACT         => 'PRAXO-CORE (praxocore): Embeddable AI agent framework with tool calling and policy hooks for Perl',
    AUTHOR           => 'AxisVela <releases@axisvela.com>',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.020',
    PREREQ_PM        => {
        'JSON::PP'  => 0,
        'HTTP::Tiny' => 0,
        'File::Spec' => 0,
        'Cwd'       => 0,
    },
    META_MERGE => {
        keywords => [qw(praxo-core praxocore perl ai-agents agent-framework llm tool-calling human-in-the-loop checkpoints)],
        provides => {
            'Praxo::Core' => {
                file    => 'lib/Praxo/Core.pm',
                version => '0.8.1',
            },
        },
        resources => {
            homepage   => 'https://axisvela.github.io/praxo-core/',
            repository => 'https://github.com/axisvela/praxo-core',
            bugtracker => 'https://github.com/axisvela/praxo-core/issues',
        },
    },
);
