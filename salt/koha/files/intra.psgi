#!/usr/bin/perl

use lib("/usr/share/koha/lib");
use lib("/usr/share/koha/lib/installer");

use Plack::Builder;
use Plack::App::CGIBin;
use Plack::App::Directory;
use Plack::App::URLMap;
use Plack::Middleware::Rewrite;
use Plack::Middleware::AccessLog;
#use Plack::Middleware::Debug;
#use Plack::Middleware::Debug::MemLeak;
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

use Koha::Database;

use CGI qw(-utf8 ); # we will loose -utf8 under plack, otherwise
{
    no warnings 'redefine';
    my $old_new = \&CGI::new;
    *CGI::new = sub {
        my $q = $old_new->( @_ );
        $CGI::PARAM_UTF8 = 1;
        return $q;
    };
}

C4::Context->disable_syspref_cache();

my $intranet = Plack::App::CGIBin->new(
    root => '/usr/share/koha/intranet/cgi-bin'
);

# my $opac = Plack::App::CGIBin->new(
#     root => '/usr/share/koha/opac/cgi-bin/opac'
# );

# my $api  = Plack::App::CGIBin->new(
#     root => '/usr/share/koha/api/'
# );

builder {
    # enable 'Debug',  panels => [
    #        qw(Environment Response Timer Memory),
    #       [ 'Profiler::NYTProf', exclude => [qw(.*\.css .*\.png .*\.ico .*\.js .*\.gif)] ],
    #       [ 'DBITrace', level => 1 ],
    # ];
    enable "Plack::Middleware::Static";

	enable "Plack::Middleware::Rewrite", request => sub {
		s{^/$}{/cgi-bin/koha/mainpage.pl};
	};

	enable "Plack::Middleware::AccessLog", format => "combined";

    enable "Plack::Middleware::Static",
            path => qr{^/intranet-tmpl/}, root => '/usr/share/koha/intranet/htdocs/';

    enable 'StackTrace';
    mount "/cgi-bin/koha" => $intranet;

};