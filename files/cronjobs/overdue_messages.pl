#!/usr/bin/perl -w
#
# cronjob: overdue_messages.pl
# This job handles cronjob for overduerules
# Sends notices for patrons with overdues and/or fines
# It also adds debarments

use Modern::Perl;
use strict;
use warnings;

BEGIN {
    # find Koha's Perl modules
    use FindBin;
    eval { require "$FindBin::Bin/usr/share/koha/bin/kohalib.pl" };
}
use C4::Context;
use C4::Overdues;
use Carp;

use C4::Members::Messaging;
use C4::Letters;

use Koha::Calendar;
use Koha::DateUtils;
use Koha::Purresaker;
use Koha::Libraries;

use C4::Log qw( cronlogaction );
use Template;
use utf8;
binmode( STDOUT, ":utf8" );

use Getopt::Long;

my $help;
my $verbose;

GetOptions(
    'h|help'    => \$help,
    'v|verbose' => \$verbose,
);
my $usage = << 'ENDUSAGE';

This script handles message shipment to patrons with overdues.

This script has the following parameters :
    -h --help: this message
    -v --verbose

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

cronlogaction();

# SYSPREFS
my $circControl             = C4::Context->preference('CircControl');
my $today = DateTime->now( time_zone => C4::Context->tz() );

my $totalOverdues            = 0;
my $triggeredMessages        = 0;

my %branch_holiday;
my $patrons      = Koha::Purresaker->GetPatronsWithOverdues();
my $overdueRules = Koha::Purresaker->GetOverdueRules();

# Loop each patron with at least one overdue
PATRON: while ( my $patron = $patrons->fetchrow_hashref() ) {
    # get applying circ rules for patron or item
    # Is this relevant any longer?
    my $circ_rules_branchcode =
        ( $circControl eq 'ItemHomeLibrary' ) ? $patron->{itemhomebranch}
      : ( $circControl eq 'PatronLibrary' )   ? $patron->{borrbranch}
      :                                     $patron->{branchcode};

    # Add holidays to hashmap if not already added
    if (!$branch_holiday{$circ_rules_branchcode}) {
        my $cal = Koha::Calendar->new( branchcode => $circ_rules_branchcode );
        $branch_holiday{$circ_rules_branchcode} = $cal->is_holiday($today);
    }
    # overduerules hashmap has key "borrbranch|borrcat" if not, default to "|borrcat"
    my $rule = $overdueRules->{"$patron->{borrbranch}|$patron->{borrcat}"} ? $overdueRules->{"$patron->{borrbranch}|$patron->{borrcat}"} : $overdueRules->{"|$patron->{borrcat}"};
    $rule or next; # No overduerule = no message

    use Data::Dumper;

    # We loop through overduerules backwards, oldest overdues define what message is sent
    # If days_overdue equals delay, we define a message for this patron to be sent
    PERIOD: foreach my $i ( reverse 1 .. 3 ) {
        my $delay = $rule->{"letter$i"}->{delay};
        if ($rule->{"letter$i"}->{delay}) {
            my $overdues = Koha::Purresaker->GetPatronOverdues($patron->{borrowernumber}, $rule->{"letter$i"}->{delay});
            $overdues or next PERIOD;
            my $ct = scalar @{$overdues};
            $totalOverdues += $ct;
            my $trigger = grep { $_->{days_overdue} == 29} @{$overdues};
            if ($trigger) {
                ++$triggeredMessages;
                # TODO: Send message
                next PATRON;
            }

        }
    }
}

if ($verbose) {
    my $patronsWithOverdues = $patrons->rows;
    print <<"EOM";
Overdues -- $today
Total overdues:        $totalOverdues
Patrons with overdues: $patronsWithOverdues
Triggered messages   : $triggeredMessages

EOM
}

