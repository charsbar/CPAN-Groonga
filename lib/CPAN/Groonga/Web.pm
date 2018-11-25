package CPAN::Groonga::Web;

use Mojolicious::Lite -signatures;
use CPAN::Groonga::Client;
use CPAN::Groonga;
use Scalar::Util qw/looks_like_number/;
use Data::Dump;

plugin 'DefaultHelpers';
plugin 'TagHelpers';

app->secrets([rand]);

app->attr('ua' => sub { CPAN::Groonga::Client->new });

get '/' => 'index';

get '/search' => sub ($c) {
    my %params;

    my $query = $c->req->param('q');
    return unless defined $query;

    $query =~ s/([:\-*+~<>()])/\\$1/g;
    $params{query} = $query;
    $params{match_columns} = 'tags * 1000 || scorer_tf_idf(body) * 5';

    # for pager
    my $limit = $c->req->param('limit');
    $limit = 20 if !$limit or !looks_like_number($limit);
    $limit = 100 if $limit > 100;
    my $offset = $c->req->param('offset');
    $offset = 0 if !$offset or !looks_like_number($offset);
    $offset = 1000000 if $offset > 1000000;
    $params{limit}  = $limit;
    $params{offset} = $offset;

    my @filters;
    push @filters, "distribution.is_perl6 == " . ($c->req->param('perl6') ? "true" : "false");
    push @filters, "is_special == false";
    if (my $distribution = $c->req->param('distribution')) {
        push @filters, "distribution == '$distribution'";
    }
    my $include_tests;
    my $extensions = $c->req->every_param('extension');
    if (@{$extensions // []}) {
        my @ext_filters;
        for my $extension (@$extensions) {
            $extension =~ s/\.//;
            push @ext_filters, "(extension == '$extension')";
            $include_tests = 1 if $extension eq "t";
        }
        push @filters, join ' || ', @ext_filters;
    } else {
        push @filters, 'extension != ""';
    }

    push @filters, "is_test == " . ($include_tests) ? "true" : "false";
    # TODO: regexp tag filter?

    $params{filter} = join ' && ', map {"($_)"} @filters;

    $params{sort_keys} = '-_score';
    $params{output_columns} = '_score, _key, abstract, snippet_html(body), author, distribution, time_format(distribution.released, "%Y")';

    # decrease score for older distributions
    $params{scorer} = '_score = _score + (distribution.released - now()) / 1000000000000';

    if (my $group_by = $c->req->param('group_by')) {
        if ($group_by eq 'distribution') {
            $params{drilldown} = 'distribution';
            $params{drilldown_output_columns} = '_score, _nsubrecs, _key, released, author, version, cpan_path, abstract, time_format(released, "%Y")';
            $params{drilldown_sort_keys} = '-_score, -released, _key';
            $params{drilldown_limit} = $limit;
            $params{drilldown_offset} = $offset;
            $params{output_columns} = '_score, _key, distribution';
            $params{limit} = 0;  # fetch only drilled-down distributions
        }
    }

    my $res = app->ua->select(files => \%params);

    $c->stash(res => $res);
    $c->stash(limit => $limit);
    $c->stash(offset => $offset);
} => 'search';

get '/source/*file' => sub ($c) {
    my $file = $c->stash('file');
    my $res = app->ua->select(files => {
        query          => $file,
        match_columns  => '_key',
        output_columns => 'body',
    });
    $c->stash(code => $res->{rows}[0]{body});
    $c->stash(file => $file);
    $c->stash(res => $res);
} => 'source';

1;

__DATA__

@@ layouts/default.html.ep
<!doctype html>
<html>
<head>
<title>Yet Another CPAN Grep</title>
% if (CPAN::Groonga->instance->use_cdn) {
%= stylesheet '//unpkg.com/spectre.css/dist/spectre.min.css';
%= stylesheet '//unpkg.com/spectre.css/dist/spectre-exp.min.css';
%= stylesheet '//unpkg.com/spectre.css/dist/spectre-icons.min.css';
% } else {
%= stylesheet '/css/spectre.min.css';
%= stylesheet '/css/spectre-exp.min.css';
%= stylesheet '/css/spectre-icons.min.css';
% }
%= stylesheet begin
span.keyword { font-weight: bold; color: #f00 }
.tile-content { overflow: auto }
% end
</head>
<body>
<header class="navbar">
  <section class="navbar-section">
    <h1><a class="navbar-brand m-2" href="/">CPAN::Groonga</a></h1>
  </section>
</header>
<div class="container">
  <div class="columns">
    <div class="column col-10">
%= form_for search => begin
      <div class="input-group">
        <%= text_field 'q', class => "form-input" %>
        <%= submit_button 'Grep', class => "input-group-btn btn btn-primary" %>
      </div>
      <div class="form-group">
        <label class="form-switch">
            %= check_box "perl6";
            <i class="form-icon"></i>Perl 6
        </label>
      </div>
      <div class="accordion">
        <input type="checkbox" id="advanced" hidden>
        <label class="accordion-header" for="advanced">Advanced options <i class="icon icon-arrow-right"></i></label>
        <div class="accordion-body">
          <div class="form-group">
          Group
          <label class="form-checkbox form-inline">
            <%= check_box group_by => "distribution" %><i class="form-icon"></i> by distribution
          </label>
          </div>
          <div class="form-group">
          <div>Extension</div>
          % for my $ext (qw/pm pod pl t xs h pm6 pod6 pl6/) {
            % if ($ext eq 'pm6') {
              <br>
            % }
          <label class="form-checkbox form-inline">
            <%= check_box extension => $ext %><i class="form-icon"></i> <%= $ext %>
          </label>
          % }
          </div>
        </div>
      </div>
% end

%== content

    </div>
  </div>
</div>
<hr>
<div class="container">
  <p>Powered by <a href="http://groonga.org">Groonga</a></p>
  <p>Maintained by Kenichi Ishigaki &lt;ishigaki@cpan.org&gt;. If you find anything, submit it on <a href="https://github.com/charsbar/CPAN-Groonga/issues">GitHub</a>.</p>
</div>
</body>
</html>

@@ index.html.ep
% layout 'default';
<div class="empty">
  <p class="empty-title h5">Usage</p>
  <dl>
    <dt>AND condition</dt>
    <dd>
      Just enter words in the search box.
      <code>open FH</code>
    </dd>
    <dt>OR condition</dt>
    <dd>
      Put OR (uppercase only) between words.
      <code>->@* OR ->%*</code>
    </dd>
    <dt>Exact phrase</dt>
    <dd>
      Put words in double quotes.
      <code>"push @INC"</code>
    </dd>
    <dt>Escape</dt>
    <dd>
      Put a backslash before a special character (notably, backslash and double quote).
      <code>\"</code>
    </dd>
  </dl>
</div>

@@ search.html.ep
% layout 'default';
% my $res = stash('res') // {};
% my @rows = @{ $res->{rows} // [] };
% my $total = $res->{rows_total};

</p>Matches <%= $total %></p>
% if (@rows) {
%   for my $row (@rows) {
<div class="tile m-2">
  <div class="tile-content">
%     if ($row->{_nsubrecs}) {
%       # group by distribution
    <div class="tile-title">
      <a href="<%= url_with->query({group_by => '', distribution => $row->{_key} }) %>"><%= $row->{author} %>/<%= $row->{_key} %>-<%= $row->{version} %></a> <small>(<%= $row->{time_format} %>; matches <%= $row->{_nsubrecs} %> files)</small>
    </div>
    <div class="tile-subtitle">
      <%= $row->{abstract} %>
    </div>
%     } else {
%   # file
    <div class="tile-title">
      <a href="<%= url_with->query({distribution => $row->{distribution}, group_by => 'distribution'}) %>"><%= $row->{distribution} %></a> <small>(<%= $row->{author} %>, <%= $row->{time_format} %>)</small>
      <div><small><%= $row->{_key} %> (<a href="<%= url_with->path("/source/$row->{_key}") %>">view source</a>)</small></div>
    </div>
%       my @snippets = @{ $row->{snippet_html} // [] };
%       if (@snippets) {
    <div class="tile-subtitle">
%         for my $snippet (@snippets) {
      <pre class="code"><code><%== $snippet %></code></pre>
%         }
    </div>
%       }
%     }
  </div>
</div>
%   }
% }

% if ($total) {
%   my $offset = stash('offset') || 0;
%   my $limit  = stash('limit')  || 20;
%   my $current = int($offset / $limit) + 1;
%   my $max = int($total / $limit) + 1;
<ul class="pagination">
%   if ($current > 1) {
  <li class="page-item page-prev"><a href="<%= url_with->query({offset => ($current - 2) * $limit}) %>">Previous</a></li>
%   }
% if ($current > 4) {
  <li class="page-item"><a href="<%= url_with->query({offset => 0}) %>">1</a></li>
% }
% if ($current > 5) {
  <li class="page-item"><span>...</span></li>
% }
% for my $ct (-3 .. +3) {
%   my $page = $current + $ct;
%   if ($page > 0 and $page < $max and $page != $current) {
  <li class="page-item"><a href="<%= url_with->query({offset => ($page - 1) * $limit}) %>"><%= $page %></a></li>
%   } elsif ($page == $current) {
  <li class="page-item active"><a href="#"><%= $current %></a></li>
%   }
% }
% if ($max > $current + 4) {
  <li class="page-item"><span>...</span></li>
% }
% if ($max > $current) {
  <li class="page-item"><a href="<%= url_with->query({offset => ($max - 1) * $limit}) %>"><%= $max %></a></li>
  <li class="page-item page-next"><a href="<%= url_with->query({offset => $current * $limit}) %>">Next</a></li>
% }
</ul>
% }

% if (CPAN::Groonga->instance->debug) {
<hr>
<pre class="code"><code>
%= Data::Dump::dump($res);
</code></pre>
% }

@@ source.html.ep
% layout 'default';
<%= stash('file') %>
<pre class="code"><code>
%= stash('code');
</code></pre>
