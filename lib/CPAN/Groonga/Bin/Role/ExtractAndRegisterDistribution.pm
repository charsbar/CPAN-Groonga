package CPAN::Groonga::Bin::Role::ExtractAndRegisterDistribution;

use Mojo::Base -role, -signatures;
use CPAN::Groonga::Parser;
use Parse::Distname qw/parse_distname/;
use Syntax::Keyword::Try;
use Data::Binary qw/is_binary/;
use Archive::Any::Lite;
use File::Temp ();
use Path::Extended::Tiny;
use Parse::CPAN::Meta;
use Parse::PMFile;
use Mojo::JSON qw/decode_json/;
use Encode;

my %SpecialFiles = map {$_ => 1} qw/
    Makefile.PL
    Build.PL
    META.yml
    META.json
    META6.json
    cpanfile
    dist.ini
/;

with qw/CPAN::Groonga::Role::Log/;

sub extract_and_register_distribution ($self, $archive_file) {
    my $tmpdir = dir(File::Temp::tempdir(CLEANUP => 1));
    my $archive = Archive::Any::Lite->new($archive_file->path);
    try {
        local $Archive::Any::Lite::IGNORE_SYMLINK = 1;
        $archive->extract($tmpdir);
        my $basedir = $tmpdir->children == 1 ? ($tmpdir->children)[0] : $tmpdir;
        $basedir = $tmpdir unless -d $basedir;
        $self->register_distribution($basedir, $archive_file);
    } catch {
        $self->log(error => "Can't extract ".$archive_file->path." $@");
    }
    $tmpdir->remove;
}

sub register_distribution ($self, $dir, $archive_file) {
    my $dist = parse_distname($archive_file) or return;

    my $name      = $dist->{name} // return;
    my $subdir    = $dist->{subdir} // '';
    my $pause_id  = $dist->{pause_id};
    my $is_perl6  = $dist->{is_perl6};
    my $cpan_path = $dist->{cpan_path};

    $is_perl6 = 1 if -e $dir->file('META6.json');

    my $id = $is_perl6 ? "Perl6/$name" : $name;

    my $mtime = $archive_file->mtime;

    $self->log(info => "registering $cpan_path");

    # Get some meta data, ignoring slight differences between specs
    my $meta = $self->_load_meta($dir) // {};
    my $abstract = $is_perl6 ? $meta->{description} : $meta->{abstract};
    my $license = $meta->{license};
    my @modules = keys %{$meta->{provides} || {}};

    my %dist_tags = (
        $pause_id => "1000",
        $name => "1000",
    );
    $dist_tags{$_} //= "100" for @modules;
    $dist_tags{$_} //= "10" for split /\-/, $name;

    $self->ua->load(distributions => [{
        _key        => $name,
        cpan_path   => $cpan_path,
        author      => $pause_id,
        version     => $dist->{version} // '',
        released    => $mtime,
        abstract    => $abstract,
        license     => $license,
        is_perl6    => $is_perl6,
        tags        => \%dist_tags,
    }]);

    my @files;
    $dir->recurse(callback => sub {
        my $file = shift;
        return unless -f $file && -r $file;
        my ($extension) = $file =~ /\.((?:pm|pod|pl|t)6?|xs|h)?$/;
        my $file_path = $file->relative($dir);
        return if $file_path =~ /^(inc|examples?|author|demo|eg|local|bundled?)\b/;
        my $is_test = $file_path =~ m!^x?t/!;
        my $is_special = $SpecialFiles{$file_path} ? 1 : 0;
        my $size = -s $file;
        my $body = '';
        my %parsed_parts;
        if ($size < 1_000_000) {
            $body = $file->slurp;
            $body = '' if is_binary($body);
            if ($body && $extension && $extension =~ /^(?:pm|pod|pl|t)$/) {
                my ($encoding) = $body =~ /^=encoding\s+(\S+)$/m;
                if ($encoding and $encoding !~ /utf\-?8/i) {
                    $self->log(info => "converted $name/$file_path from $encoding to utf8");
                    $body = decode($encoding, $body);
                } else {
                    $body = decode_utf8($body);
                }
                my $parser = CPAN::Groonga::Parser->new;
                try {
                    $parser->read_string($body);
                    for my $method (qw/code pod abstract synopsis description/) {
                        $parsed_parts{$method} = $parser->$method // '';
                    }
                }
                catch {
                    $self->log(error => "parse error: $file_path $@");
                }
            }
        }

        my %file_tags;
        if ($file_path =~ /\.pm$/ and !$is_test and !$is_perl6) {
            my $parser = Parse::PMFile->new($meta, {
                ALLOW_DEV_VERSION => 1,
            });
            my $info = $parser->parse($file);
            for my $package (keys %$info) {
                $file_tags{$package} = "100";
                $file_tags{$_} //= "20" for split '::', $package;
            }
        }

        push @files, {
            _key => "$name/$file_path",
            distribution => $name,
            author       => $pause_id,
            mtime        => $file->mtime,
            extension    => $extension,
            size         => $size,
            is_test      => $is_test,
            is_special   => $is_special,
            tags         => \%file_tags,
            body         => $body,
            %parsed_parts,
        };
    });
    while(my @parts = splice @files, 0, 1000) {
        $self->ua->load(files => \@parts);
    }
}

sub _load_meta ($self, $dir) {
    if (-f $dir->file('META6.json')) {
        my $meta = $dir->file('META6.json')->slurp or return;
        return eval { decode_json($meta) };
    } elsif (-f $dir->file('META.json')) {
        return eval { Parse::CPAN::Meta->load_file($dir->file('META.json')) };
    } elsif (-f $dir->file('META.yml')) {
        # Convert?
        return eval { Parse::CPAN::Meta->load_file($dir->file('META.json')) };
    }
    return;
}

1;
