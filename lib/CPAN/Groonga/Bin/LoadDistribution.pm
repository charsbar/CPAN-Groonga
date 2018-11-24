package CPAN::Groonga::Bin::LoadDistribution;

use Role::Tiny::With;
use Mojo::Base -base, -signatures;
use CPAN::Groonga::Client;
use CPAN::Groonga::Schema;
use Path::Extended::Tiny qw/dir/;
use Parse::Distname qw/parse_distname/;

with qw/
    CPAN::Groonga::Role::Log
    CPAN::Groonga::Bin::Role::Timer
    CPAN::Groonga::Bin::Role::ExtractAndRegisterDistribution
/;

has 'cache'    => sub { +{} };
has 'ua'       => sub { CPAN::Groonga::Client->new };
has 'cpan_dir' => sub { CPAN::Groonga->instance->cpan_dir };

sub run ($self, @args) {
    my $dir = dir($self->cpan_dir);
    my $authors_dir = $dir->subdir("authors/id");
    Carp::croak "$dir seems not a CPAN mirror" if !-d $dir or !-d $authors_dir;

    CPAN::Groonga::Schema->new->setup;

    my %target;
    for my $path (@args) {
        my $dist = parse_distname($path) or return;
        next unless $path =~ /$Parse::Distname::SUFFRE$/;
        my $name = $dist->{name} or next;
        my $file = $authors_dir->file($dist->{cpan_path});
        unless (-f $file) {
            $self->log(warn => "$path does not exists");
            next;
        }
        my $id = $dist->{is_perl6} ? "Perl6/$name" : $name;
        my $mtime = $file->mtime;
        if ($self->cache->{$id}) {
            return if $self->cache->{$id} >= $mtime;
        }
        $self->cache->{$id} = $mtime;
        $target{$id} = $file;
    }
    for my $file (sort values %target) {
        $self->extract_and_register_distribution($file);
    }
}

1;
