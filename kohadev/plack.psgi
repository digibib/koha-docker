#!/usr/bin/perl

# This file is part of Koha.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Modern::Perl;

use lib("/kohadev/kohaclone/lib");
use lib("/kohadev/kohaclone/installer");

use Plack::Builder;
use Plack::App::CGIBin;
use Plack::App::Directory;
use Plack::App::URLMap;

# Pre-load libraries
use C4::Boolean;
use C4::Branch;
use C4::Category;
use C4::Koha;
use C4::Languages;
use C4::Letters;
use C4::Members;
use C4::XSLT;
use Koha::Database;
use Koha::DateUtils;

use Mojo::Server::PSGI;
use Plack::Middleware::Debug;

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
    root => '/kohadev/kohaclone'
);

my $opac = Plack::App::CGIBin->new(
    root => '/kohadev/kohaclone/opac'
);

builder {
    # enable 'Debug',  panels => [
    #        qw(Environment Response Timer Memory),
    #       [ 'Profiler::NYTProf', exclude => [qw(.*\.css .*\.png .*\.ico .*\.js .*\.gif)] ],
    #       [ 'DBITrace', level => 1 ],
    # ];

    enable 'Debug';

    enable "ReverseProxy";
    enable "Plack::Middleware::Static";

    mount '/opac'     => $opac;
    mount '/intranet' => $intranet;
    mount '/api'      => builder {
      my $server = Mojo::Server::PSGI->new;
      $server->load_app('/kohadev/kohaclone/api/v1/app.pl');
      #$server->app->config(foo => 'bar');
      $server->to_psgi_app;
    };

};