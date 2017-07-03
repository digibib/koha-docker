#!/usr/bin/perl

use strict;
use warnings;
use lib 'lib';

use Test::More tests => 3;
BEGIN { use_ok('NCIPServer') };

ok(my $server = NCIPServer->new({config_dir => 't/config_sample'}));


# internal routines not called except by run, but we should test them
ok($server->configure_hook());


# use Data::Dumper;
# print Dumper $server;

# uncomment this if you want to run the server in test mode
# $server->run();
