use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Praxo::Agent',
    DISTNAME         => 'Praxo-Core',
    VERSION          => '0.1.0',
    ABSTRACT         => 'Embeddable MIT-licensed agent framework for Perl',
    AUTHOR           => 'AxisVela <releases@axisvela.com>',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.020',
    PREREQ_PM        => {
        'JSON::PP'  => 0,
        'File::Spec' => 0,
        'Cwd'       => 0,
    },
    META_MERGE => {
        resources => {
            homepage   => 'https://axisvela.github.io/praxo-core/',
            repository => 'https://github.com/axisvela/praxo-core',
            bugtracker => 'https://github.com/axisvela/praxo-core/issues',
        },
    },
);
