#
#===============================================================================
#
#         FILE: NCIP.t
#
#  DESCRIPTION:
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Chris Cormack (rangi), chrisc@catalyst.net.nz
# ORGANIZATION: Koha Development Team
#      VERSION: 1.0
#      CREATED: 18/09/13 09:59:01
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use File::Slurp;

use Test::More tests => 9;    # last test to print

use lib 'lib';

use_ok('NCIP');
ok( my $ncip = NCIP->new('t/config_sample'), 'Create new object' );

my $xmlbad = <<'EOT';
<xml>
this is bad
<xml>
</xml>
EOT

# handle_initiation is called as part of the process_request, but best to test
# anyway
ok( !$ncip->handle_initiation($xmlbad), 'Bad xml' );

my $lookupitem = read_file('t/sample_data/LookupItem.xml');

ok( my $response = $ncip->process_request($lookupitem),
    'Try looking up an item' );
is( $response, 'LookupItem', 'We got lookupitem' );

$lookupitem =
  read_file('t/sample_data/LookupItemWithExampleItemIdentifierType.xml');
ok(
    $response = $ncip->process_request($lookupitem),
    'Try looking up an item, with agency'
);
is( $response, 'LookupItem', 'We got lookupitem with agency' );

my $lookupuser = read_file('t/sample_data/LookupUser.xml') || die "Cant open file";
ok( $response = $ncip->process_request($lookupuser), 'Try looking up a user' );
is( $response, 'FLO-WHEELOCK', 'Got the user we expected' );

