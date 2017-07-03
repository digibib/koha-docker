#!/usr/bin/perl 
#===============================================================================
#
#         FILE: test_server.pl
#
#        USAGE: ./test_server.pl
#
#  DESCRIPTION:
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Chris Cormack (rangi), chrisc@catalyst.net.nz
# ORGANIZATION: Koha Development Team
#      VERSION: 1.0
#      CREATED: 28/08/13 14:12:51
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use lib "lib";

use NCIPServer;
use Getopt::Long;

my $help;
my $config_dir;

GetOptions(
    'h|help'     => \$help,
    'c|config:s' => \$config_dir,
);
my $usage = << 'ENDUSAGE';

This script will start an NCIP server, using the configuration set in the config dir you pass

This script has the following parameters :
    -h --help:   this message
    -c --config: path to the configuration directory

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

if ( !$config_dir ) {
    print "You must specify a configuration directory\n";
    print $usage;
    exit;
}

my $server = NCIPServer->new( { config_dir => $config_dir } );

$server->run();
