requires 'Archive::Any::Lite';
requires 'Data::Binary';
requires 'Data::Dump';
requires 'Encode';
requires 'File::Temp';
requires 'JSON::PP';
requires 'JSON::XS';
requires 'List::Util' => '1.29';
requires 'Log::Handler';
requires 'Log::Handler::Output::File::Stamper';
requires 'Mojolicious' => '8.00';
requires 'MooX::Singleton';
requires 'Parse::CPAN::Meta';
requires 'Parse::CPAN::Whois';
requires 'Parse::Distname' => '0.03';
requires 'Path::Extended::Tiny';
requires 'Plack::Middleware::AxsLog';
requires 'Plack::Middleware::ReverseProxy';
requires 'Pod::Stupid';
requires 'Role::Tiny';
requires 'Syntax::Keyword::Try';
requires 'Time::Duration';
requires 'Time::HiRes';
requires 'WorePAN';

recommends 'Starman';

on 'test' => sub {
    requires 'Test::More' => '0.88'; # for done_testing
    requires 'Test::UseAllModules' => '0.10';
};

on 'configure' => sub {
    requires 'ExtUtils::MakeMaker::CPANfile';
};

on 'develop' => sub {
    requires 'Test::CPANfile' => '0.02';
    requires 'Perl::PrereqScanner::NotQuiteLite' => '0.97';
};
