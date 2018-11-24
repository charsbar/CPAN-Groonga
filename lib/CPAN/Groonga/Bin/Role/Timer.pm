package CPAN::Groonga::Bin::Role::Timer;

use Mojo::Base -role, -signatures;
use Time::Duration;
use Time::HiRes qw/time/;

with qw/CPAN::Groonga::Role::Log/;

has 'pid';

around run => sub ($orig, $self, @args) {
    my ($name) = (ref $self // $self) =~ /^CPAN::Groonga::Bin::(.+)$/;
    $self->log(notice => "$name started");
    my $start = time;
    $self->pid($$);
    my $ret = $orig->($self, @args);
    return if $self->pid != $$;
    local $Time::Duration::MILLISECOND = 1;
    my $elapsed = duration(time - $start);
    $self->log(notice => "$name ended: $elapsed");
};

1;
