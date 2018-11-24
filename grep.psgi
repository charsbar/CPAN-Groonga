use Mojo::Base -strict, -signatures;
use FindBin;
use lib "$FindBin::Bin/lib";
use Plack::Builder;
use CPAN::Groonga;
use CPAN::Groonga::Web;
use Mojo::Util qw/getopt/;

local $ENV{MOJO_REVERSE_PROXY} = 1;
local $ENV{MOJO_HOME} = "$FindBin::Bin";

CPAN::Groonga->instance;

my $app = CPAN::Groonga::Web->new;

builder {
    enable "ReverseProxy";
    if (CPAN::Groonga->instance->serve_static) {
        enable "Static",
            path => qr!^/(?:images|js|css)/!, root => "$FindBin::Bin/public";
    }
    enable "AxsLog",
        combined => 1,
        response_time => 1,
        long_response_time => 1000000;
    $app->start('psgi');
};
