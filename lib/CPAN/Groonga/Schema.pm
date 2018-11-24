package CPAN::Groonga::Schema;

use Role::Tiny::With;
use Mojo::Base -base, -signatures;
use CPAN::Groonga::Client;

with qw/CPAN::Groonga::Role::Log/;

has 'ua' => sub { CPAN::Groonga::Client->new };

has 'tables' => sub { return [
    {
        name    => 'authors',
        columns => {
            _key       => { type => 'ShortText' }, # pause_id
            name       => { type => 'ShortText' },
            ascii_name => { type => 'ShortText' },
            introduced => { type => 'Time' },
        },
    },
    {
        name    => 'distributions',
        columns => {
            _key        => { type => 'ShortText' }, # name
            cpan_path   => { type => 'ShortText' },
            author      => { type => 'authors' },
            version     => { type => 'ShortText' },
            released    => { type => 'Time' },
            abstract    => { type => 'ShortText' },
            license     => { type => 'ShortText' },
            is_perl6    => { type => 'Bool' },
            tags        => { type => 'ShortText', flags => 'COLUMN_VECTOR|WITH_WEIGHT' },
        },
    },
    {
        name => 'files',
        columns => {
            _key         => { type => 'ShortText' },
            distribution => { type => 'distributions' },
            author       => { type => 'authors' },
            mtime        => { type => 'Time' },
            size         => { type => 'UInt32' },
            extension    => { type => 'ShortText' },
            is_test      => { type => 'Bool' },
            is_special   => { type => 'Bool' },
            body         => { type => 'LongText' },
            code         => { type => 'LongText' },
            pod          => { type => 'LongText' },
            abstract     => { type => 'ShortText' },
            synopsis     => { type => 'Text' },
            description  => { type => 'Text' },
            tags         => { type => 'ShortText', flags => 'COLUMN_VECTOR|WITH_WEIGHT' },
        },
    },
    {
        name              => 'terms',
        default_tokenizer => 'TokenBigram',
        normalizer        => 'NormalizerAuto',
        indexes => {
            author_names => 'authors.ascii_name',
            dist_tags    => { for => 'distributions.tags', flags => 'COLUMN_INDEX|WITH_WEIGHT' },
            file_tags    => { for => 'files.tags', flags => 'COLUMN_INDEX|WITH_WEIGHT' },
            body         => 'files.body',
            code         => 'files.code',
            pod          => 'files.pod',
        },
    },
]};

sub setup ($self) {
    my $mapping = $self->fetch_schema;

    for my $table (@{ $self->tables }) {
        my $table_name = $table->{name} or Carp::croak "No table name";
        next if $table_name =~ /^_/;
        if (!exists $mapping->{$table_name}) {
            my %args;
            for my $key (keys %$table) {
                next if $key =~ /(?:columns|indexes)/;
                $args{$key} = $table->{$key};
            }
            if (exists $table->{columns} and exists $table->{columns}{_key}) {
                $args{key_type} //= $table->{columns}{_key}{type};
            }
            $args{key_type} //= 'ShortText';
            $args{flags} //= exists $table->{indexes} ? 'TABLE_PAT_KEY' : 'TABLE_HASH_KEY';

            $self->ua->table_create($table_name, \%args);
        }

        for my $type (qw/columns indexes/) {
            next unless exists $table->{$type};
            my $columns = $table->{$type};
            for my $column_name (keys %$columns) {
                next if $column_name =~ /^_/;
                next if $mapping->{$table_name}{$column_name};
                my %args = (
                    table => $table_name,
                    name  => $column_name,
                );
                if (ref $columns->{$column_name}) {
                    $args{$_} = $columns->{$column_name}{$_} for keys %{$columns->{$column_name}};
                    if ($args{for}) {
                        @args{qw/type source/} = split '\.', delete $args{for};
                    }
                } else {
                    @args{qw/type source/} = split '\.', $columns->{$column_name};
                }
                $args{flags} //= ($type eq 'indexes') ? 'COLUMN_INDEX|WITH_POSITION' : 'COLUMN_SCALAR';

                $self->ua->column_create($column_name, \%args);
            }
        }
    }

    $self->ua->get(plugin_register => {name => "functions/time"});
}

sub fetch_schema ($self) {
    my %mapping;
    my $schema = $self->ua->schema;
    for my $table_name (keys %{$schema->{tables} // {}}) {
        my $table = $schema->{tables}{$table_name};
        for my $column_name (keys %{$table->{columns}}) {
            $mapping{$table_name}{$column_name} = 1;
        }
    }
    \%mapping;
}

1;
