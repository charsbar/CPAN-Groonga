use Mojo::Base -strict;
use FindBin;
use Test::More;
use CPAN::Groonga::Parser;

my $parser = CPAN::Groonga::Parser->new;
$parser->read_file("$FindBin::Bin/../lib/CPAN/Groonga.pm");

ok $parser->pod, "pod";
ok $parser->code, "code";
ok $parser->abstract, "abstract";
ok $parser->synopsis, "synopsis";
ok $parser->description, "description";

# note explain $parser;

done_testing;

