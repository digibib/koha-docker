#!/usr/bin/perl
use Plack::Builder;
use Plack::App::CGIBin;
use Plack::App::Directory;
use Plack::Middleware::Rewrite;
#use Plack::Middleware::Debug;
#use Plack::Middleware::Debug::MemLeak;
use lib("/usr/share/koha/lib");
use C4::Context;
use C4::Languages;
use C4::Members;
use C4::Dates;
use C4::Boolean;
use C4::Letters;
use C4::Koha;
use C4::XSLT;
use C4::Branch;
use C4::Category;

my $app=Plack::App::CGIBin->new(root => "/usr/share/koha/intranet/cgi-bin/");

builder {
#        enable 'Debug',  panels => [
#                qw(Environment Response Timer Memory),
#               [ 'Profiler::NYTProf', exclude => [qw(.*\.css .*\.png .*\.ico .*\.js .*\.gif)] ],
#               [ 'DBITrace', level => 1 ],
#        ];

		enable "Plack::Middleware::Rewrite", request => sub {
			s{^/$}{/cgi-bin/koha/mainpage.pl};
		};


        enable "Plack::Middleware::Static",
                path => qr{^/intranet-tmpl/}, root => '/usr/share/koha/intranet/htdocs/';                

#       enable "Plack::Middleware::Static::Minifier",
#               path => qr{^/intranet-tmpl/},
#               root => './koha-tmpl/';

        enable 'StackTrace';
        mount "/cgi-bin/koha" => $app;

};