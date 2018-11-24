package CPAN::Groonga::Role::Log;

use Mojo::Base -role, -signatures;
use CPAN::Groonga;

sub log ($self, $level, $message) {
    CPAN::Groonga->instance->log($level, $message);
}

1;
