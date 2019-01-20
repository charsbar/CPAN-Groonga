package CPAN::Groonga::Bin::LoadCPAN;

use Role::Tiny::With;
use Mojo::Base -base, -signatures;
use CPAN::Groonga::Client;
use CPAN::Groonga::Schema;
use Path::Extended::Tiny qw/dir/;
use Parse::Distname qw/parse_distname/;
use Parse::CPAN::Whois;

with qw/
    CPAN::Groonga::Role::Log
    CPAN::Groonga::Bin::Role::Timer
    CPAN::Groonga::Bin::Role::ExtractAndRegisterDistribution
/;

has 'cache'    => sub { +{} };
has 'ua'       => sub { CPAN::Groonga::Client->new };
has 'cpan_dir' => sub { CPAN::Groonga->instance->cpan_dir or Carp::croak "requires cpan_dir" };

sub run ($self, @args) {
    my $dir = dir($self->cpan_dir);
    my $authors_dir = $dir->subdir("authors/id");
    Carp::croak "$dir seems not a CPAN mirror" if !-d $dir or !-d $authors_dir;

    CPAN::Groonga::Schema->new->setup;

    my @authors;
    my $whois = $dir->file('authors/00whois.xml');
    if (-f $whois) {
        for my $author ( Parse::CPAN::Whois->new($whois->path)->authors ) {
            push @authors, {
                _key => $author->{id},
                name => $author->{fullname} // $author->{asciiname} // $author->{id},
                ascii_name => $author->{asciiname} // '',
                introduced => $author->{introduced} // 0,
            };
        }
        $self->ua->load(authors => \@authors);
    }

    if (!@authors) {
        for my $first ($authors_dir->children) {
            for my $second ($first->children) {
                for my $pause_id ($second->children) {
                    push @authors, {
                        _key => $pause_id->basename,
                    };
                }
            }
        }
    }

    for my $author (sort {$a->{_key} cmp $b->{_key}} @authors) {
        my $pause_id = $author->{_key};
        my $author_dir = $authors_dir->subdir(join '/', substr($pause_id, 0, 1), substr($pause_id, 0, 2), $pause_id);
        next unless -d $author_dir;
        $self->log(info => "looking for $pause_id distributions");

        my %target;
        $author_dir->recurse(callback => sub {
            my $file = shift;
            return unless -f $file;
            return unless $file =~ /$Parse::Distname::SUFFRE$/;
            my $dist = parse_distname($file->path) or return;
            my $name = $dist->{name} or return;
            my $id = $dist->{perl6} ? "Perl6/$name" : $name;
            my $mtime = $file->mtime;
            if ($self->cache->{$id}) {
                return if $self->cache->{$id} >= $mtime;
            }
            $self->cache->{$id} = $mtime;
            $target{$id} = $file;
        });
        for my $file (sort values %target) {
            $self->extract_and_register_distribution($file);
        }
    }
}

1;
