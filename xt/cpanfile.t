use Mojo::Base -strict;
use lib glob "extlib/*/lib";
use Test::More;
use Test::CPANfile 0.02;
use CPAN::Common::Index::Mirror;

my $index = CPAN::Common::Index::Mirror->new;

cpanfile_has_all_used_modules(
        parsers => [':bundled', 'CPANGroonga'],
        libs => [glob "extlib/*/lib"],
        index => $index,
);

done_testing;

package Perl::PrereqScanner::NotQuiteLite::Parser::CPANGroonga;

use strict;
use warnings;
use Perl::PrereqScanner::NotQuiteLite::Util;

sub register { return +{
    use => {
        'CPAN::Groonga' => sub { return },
    },
}}
