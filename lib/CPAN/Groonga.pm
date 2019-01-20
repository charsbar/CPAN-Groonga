package CPAN::Groonga;

use Role::Tiny::With;
use Mojo::Base -base, -signatures;
use Mojo::Home;
use Data::Dump ();
use List::Util 1.29 qw/pairs/;
use Log::Handler;

our $VERSION = '0.01';

with qw/MooX::Singleton/;

has 'logger' => \&_build_logger;
has 'config' => \&_build_config;
has 'home'   => sub { Mojo::Home->new };

my %OptionSpec = (
    'verbose|v'    => undef,
    'debug'        => undef,
    'server_url=s' => 'http://localhost:10041',
    'cpan_dir=s'   => "$ENV{HOME}/cpan",
    'use_cdn'      => undef,
    'serve_static' => undef,
);

my @OptionNames;
for my $key (keys %OptionSpec) {
    my ($name) = $key =~ /^(\w+)/;
    push @OptionNames, $name;
    has $name => sub ($self) {
        $self->{$name} //= $self->config->{$name} // $OptionSpec{$key};
    };
}

sub options ($self) { keys %OptionSpec }
sub option_names ($self) { @OptionNames }

sub _build_logger ($self) {
    my @config = @{$self->config->{logger} // []};
    my $log_dir = $self->home->rel_file("log");
    $log_dir->make_path unless -d $log_dir;

    # default loggers
    push @config, map {(
        file => {
            filename => "LOGDIR/${_}_%d{yyyyMM}.log",
            minlevel => $_,
            maxlevel => $_,
        },
    )} qw/alert error warning notice/;

    if ($self->verbose) {
        push @config, (
            screen => {
                log_to   => 'STDERR',
                minlevel => 'emergency',
                maxlevel => 'info',
            },
        );
    }

    if ($self->debug) {
        push @config, (
            screen => {
                log_to   => 'STDERR',
                minlevel => 'debug',
                maxlevel => 'debug',
            },
            file => {
                filename => "LOGDIR/debug_%d{yyyyMMdd_HH}.log",
                minlevel => 'info',
                maxlevel => 'debug',
            },
        );
    }

    my @handler_config;
    for my $pair (pairs @config) {
        my ($class, $conf) = @$pair;
        if ($class eq 'file') {
            if ($conf->{filename} =~ /LOGDIR/) {
                $conf->{filename} =~ s/LOGDIR/$log_dir/;
            }
            if ($conf->{filename} =~ /%d\{/) {
                $class = 'Log::Handler::Output::File::Stamper';
                $conf->{timeformat} //= '%Y-%m-%d %H:%M:%S';
            }
        } elsif ($class eq 'email_sender') {
            $class = 'Log::Handler::Output::Email::Sender';
            if (my $email_from = $self->config->{email_from}) {
                $conf->{from} //= $email_from;
            }
            if (my $email_to = $self->config->{email_to}) {
                $conf->{to} //= $email_to;
            }
        }
        $conf->{message_layout} //= '%T %L %m';
        $conf->{timeformat} //= '%Y-%m-%d %H:%M:%S';
        push @handler_config, $class, $conf;
    }

    Log::Handler->new(@handler_config);
}

sub _build_config ($self) {
    my %config;
    my $file = $self->home->rel_file("etc/config.pl");
    if (-f $file) {
        %config = %{ do "$file" };
    }
    \%config;
}

sub dump ($self, $obj) { say STDERR Data::Dump::dump($obj) }

sub log ($self, $level, $message) {
    $self->logger->log($level, ref $message ? Data::Dump::dump($message) : $message);
}

sub DESTROY ($self) {
    $self->logger->flush if $self->{logger};
}

1;

__END__

=encoding utf-8

=head1 NAME

CPAN::Groonga - search CPAN using Groonga

=head1 SYNOPSIS

    use CPAN::Groonga;

=head1 DESCRIPTION

This is yet another CPAN search site.

=head1 AUTHOR

Kenichi Ishigaki, E<lt>ishigaki@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2018 by Kenichi Ishigaki.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
