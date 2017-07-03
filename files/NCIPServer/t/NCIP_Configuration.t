#
#===============================================================================
#
#         FILE: NCIP_Configuration.t
#
#  DESCRIPTION:
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Chris Cormack (rangi), chrisc@catalyst.net.nz
# ORGANIZATION: Koha Development Team
#      VERSION: 1.0
#      CREATED: 28/08/13 10:35:44
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use Sys::Syslog;
use lib 'lib';

use Test::More tests => 5;    # last test to print

use_ok('NCIP::Configuration');

ok( my $config = NCIP::Configuration->new('t/config_sample'),
    'Creating a config object' );

# because the file is called NCIP.xml we now have that namespace
ok( my $server_params = $config->('NCIP.server-params'), 'Get server-params' );

is( $server_params->{'min_servers'}, 1, 'Do we have a minimum of one server' );

ok ($config->find_service('127.0.0.1','6001','tcp'),'Testing find_service');

