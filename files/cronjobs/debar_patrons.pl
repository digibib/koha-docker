#!/usr/bin/perl -w
#
# cronjob: debar_patrons.pl
# This job handles debarments according to overduerules
# Mainly a replica of the logic in overdue_messages.pl

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

use Koha::Calendar;
use Koha::DateUtils;
use Koha::Purresaker;
use Koha::Patron::Debarments qw(AddUniqueDebarment);

use C4::Log qw( cronlogaction );
use utf8;
binmode( STDOUT, ":utf8" );

use Getopt::Long;

my $help;
my ($verbose, $test_mode) = (0,0);

GetOptions(
    'h|help'    => \$help,
    'v|verbose' => \$verbose,
    't|test'    => \$test_mode,
);
my $usage = << 'ENDUSAGE';

This script handles message shipment to patrons with overdues.

This script has the following parameters :
    -h --help:      this message
    -v --verbose:   more output
    -t --test:      test mode, don't debar

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

cronlogaction();

# SYSPREFS
my $circControl  = C4::Context->preference('CircControl');
my $from_address = C4::Context->preference('KohaAdminEmailAddress');

my $today = DateTime->now( time_zone => C4::Context->tz() );

my ($totalOverdues,$triggeredOverdues,$patronsDebarred) = (0,0,0);

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

    # We loop through overduerules backwards, oldest overdues define what message is sent
    # 1 - If we have any overdue passed letter3 give this notice, otherwise check letter2, etc..
    # 2 - If days_overdue equals delay, we define a message for this patron to be sent
    PERIOD: foreach my $i ( reverse 1 .. 3 ) {
        my $delay  = $rule->{"letter$i"}->{delay};
        my $letter = $rule->{"letter$i"}->{letter};
        if ($rule->{"letter$i"}->{delay}) {
            my $overdues = Koha::Purresaker->GetPatronOverdues($patron->{borrowernumber}, $rule->{"letter$i"}->{delay});
            $overdues or next PERIOD;
            my $ct = scalar @{$overdues};
            $totalOverdues += $ct;
            # Check if we have an overdue that matches this delay trigger, otherwise move to next
            my ($trigger) = grep { $_->{days_overdue} == $rule->{"letter$i"}->{delay} } @{$overdues};

            if ($trigger) {
                ++$triggeredOverdues;
                if ($rule->{"letter$i"}->{debar}) {
                    $verbose and print "debarring patron " .$patron->{borrowernumber}. "\tcategory: ".$patron->{borrcat}."\trule: " .$rule->{"letter$i"}->{delay}. "\tdays_overdue: " . $trigger->{days_overdue}. "\n";
                    $test_mode or Koha::Patron::Debarments::AddUniqueDebarment({
                        borrowernumber => $patron->{borrowernumber},
                        type           => 'OVERDUES',
                        comment => "OVERDUES_PROCESS " .  _today(),
                    });
                    ++$patronsDebarred;
                    next PATRON;
                }
            }
        }
    }
}

sub _today {
    return DateTime->now()->strftime('%d.%m.%Y');
}

my $patronsWithOverdues = $patrons->rows;
$test_mode and print "TEST MODE\n";
print <<"EOM";
Debarment Cronjob -- $today
Total overdues:         $totalOverdues
Patrons with overdues:  $patronsWithOverdues
Triggered overdues:     $triggeredOverdues
Patrons debarred:       $patronsDebarred

EOM
