package CPAN::Groonga::Bin::LoadRecent;

use Role::Tiny::With;
use Mojo::Base -base, -signatures;
use CPAN::Groonga::Client;
use Path::Extended::Tiny qw/dir/;
use Mojo::JSON qw/decode_json/;
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

    my $recent_json = $dir->child('RECENT-6h.json');
    Carp::croak "$recent_json does not exist" if !-e $recent_json;

    for my $recent (@{ decode_json($recent_json->slurp)->{recent} // [] }) {
        my $path = $recent->{path};
        next unless $path =~ m!^authors/id/!;
        next unless $path =~ /$Parse::Distname::SUFFRE$/;
        my $dist = parse_distname($path) or next;
        my $name = $dist->{name} or next;
        my $id = $dist->{is_perl6} ? "Perl6/$name" : $name;

        my $archive_file = $dir->file($path);
        next unless -f $archive_file;
        my $mtime = $archive_file->mtime;

        if ($self->cache->{$id}) {
            next if $self->cache->{$id} >= $mtime;
        }
        $self->cache->{$id} = $mtime;

        $self->extract_and_register_distribution($archive_file);
    }
}

1;
