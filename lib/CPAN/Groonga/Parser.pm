package CPAN::Groonga::Parser;

use Mojo::Base 'Pod::Stupid', -signatures;
use Mojo::File 'path';

has [qw/code pod abstract synopsis description/] => '';

sub new ($class) { bless {}, $class }

sub read_file ($self, $file) {
    $self->read_string(path($file)->slurp);
}

sub read_string ($self, $string) {
    my $block_name;
    for my $piece (@{ $self->parse_string($string) // [] }) {
        if ($piece->{is_pod}) {
            $self->pod( $self->pod . $piece->{orig_txt} );

            if ($piece->{cmd_type} and $piece->{cmd_type} eq 'head') {
                ($block_name) = $piece->{orig_txt} =~ /^\A=head1\s+(NAME|SYNOPSIS|DESCRIPTION)\s*\n/s;
                next;
            }
            next unless $block_name;
            my $text = $piece->{paragraph} // '';
            $text =~ s/\s+$//s;
            if ($block_name eq 'NAME') {
                my ($package, $abstract) = split /\s+\-\s+/, $text;
                $self->abstract($abstract) unless $self->abstract;
                next;
            }
            my $method = lc $block_name;
            $self->$method($text) unless $self->$method;
        } else {
            $self->code( $self->code . $piece->{orig_txt} );
        }
    }
}

1;
