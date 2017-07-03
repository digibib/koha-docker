#
#===============================================================================
#
#         FILE: NCIP_Handler.t
#
#  DESCRIPTION:
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Chris Cormack (rangi), chrisc@catalyst.net.nz
# ORGANIZATION: Koha Development Team
#      VERSION: 1.0
#      CREATED: 19/09/13 11:32:01
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use Test::More tests => 4;    # last test to print
use lib 'lib';

use_ok('NCIP::Handler');
my $namespace = 'http://test';

my $type = 'LookupItem';

ok(
    my $handler =
      NCIP::Handler->new( { namespace => $namespace, type => $type } ),
    'Create new LookupItem handler'
);
ok( my $response = $handler->handle() );

$type = 'LookupUser';
ok(
    $handler = NCIP::Handler->new( { namespace => $namespace, type => $type } ),
    'Create new LookupItem handler'
);
ok( $response = $handler->handle() );

