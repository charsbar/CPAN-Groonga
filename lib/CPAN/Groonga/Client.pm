package CPAN::Groonga::Client;

use Role::Tiny::With;
use Mojo::Base -base, -signatures;
use Mojo::UserAgent;
use Mojo::JSON qw/decode_json/;
use Mojo::URL;
use CPAN::Groonga;

with qw/CPAN::Groonga::Role::Log/;

has 'ua'         => sub { Mojo::UserAgent->new(inactivity_timeout => 0) };
has 'server_url' => sub { CPAN::Groonga->instance->server_url };

sub get ($self, $command, $args = {}) {
    my $url = Mojo::URL->new($self->server_url);
    $url->path("/d/$command");
    $url->query(%$args);
    $self->log(info => "GET: $url");
    my $res = $self->ua->get($url)->result;
    if ($res->is_error) {
        $self->log(error => $res->message . ' ' . $res->body);
    }
    return decode_json($res->body);
}

sub post ($self, $command, $args, $content) {
    my $url = Mojo::URL->new($self->server_url);
    $url->path("/d/$command");
    $url->query(%$args);
    $self->log(info => "POST: $url");
    my $res = $self->ua->post($url => json => $content)->result;
    if ($res->is_error) {
        $self->log(error => $res->message . ' ' . $res->body);
    }
    return decode_json($res->body);
}

sub schema ($self) {
    my ($header, $schema) = @{ $self->get('schema') };
    return $schema;
}

sub table_create ($self, $table, $args) {
    $self->get('table_create', $args);
}

sub column_create ($self, $table, $args) {
    $self->get('column_create', $args);
}

sub load ($self, $table, $rows) {
    $self->post('load', {table => $table}, $rows);
}

sub select ($self, $table, $args = {}) {
    $args->{table} = $table;
    my ($header, $result) = @{ $self->get('select', $args) };
    my %res;
    if ($header->[0]) { # Error
        $res{error} = $header->[3];
    } else {
        my ($rows, $drilldown) = @$result;
        $rows = _hashify($rows) if $rows;
        if ($drilldown) {
            $drilldown = _hashify($drilldown);
            my %map;
            for my $row (@{$rows->{rows} // []}) {
                push @{$map{$row->{distribution}} //= []}, $row;
            }
            $rows = $drilldown;
            for my $row (@{$rows->{rows} // []}) {
                $row->{files} = $map{$row->{_key}};
            }
        }
        %res = %$rows;
    }
    return \%res;
}

sub _hashify ($data) {
    my %res;
    my ($total, $column_def, @arrays) = @$data;
    my @col_names = map { $_->[0] } @$column_def;
    my @rows = map { my %row; @row{@col_names} = @$_; \%row } @arrays;
    $res{rows} = \@rows;
    $res{rows_total} = $total->[0];
    \%res;
}

1;
