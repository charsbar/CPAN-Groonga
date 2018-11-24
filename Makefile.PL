use strict;
use warnings;
use ExtUtils::MakeMaker::CPANfile;

WriteMakefile(
    NAME          => 'CPAN::Groonga',
    AUTHOR        => 'Kenichi Ishigaki <ishigaki@cpan.org>',
    VERSION_FROM  => 'lib/CPAN/Groonga.pm',
    ABSTRACT_FROM => 'lib/CPAN/Groonga.pm',
    LICENSE       => 'perl',
    META_MERGE => {
        resources => {
            repository => 'https://github.com/charsbar/CPAN-Groonga',
            bugtracker => 'https://github.com/charsbar/CPAN-Groonga/issues',
        },
    },
);
