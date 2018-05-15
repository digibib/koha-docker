#!/usr/bin/perl -w
#
# cronjob: purresaker.pl
# This job adds fines to patrons that have overdues

use Modern::Perl;
use strict;
use warnings;

BEGIN {
    # find Koha's Perl modules
    use FindBin;
    eval { require "$FindBin::Bin/usr/share/koha/bin/kohalib.pl" };
}
use POSIX qw( floor ceil );
use C4::Context;
use C4::Overdues;
use Carp;

use Koha::Calendar;
use Koha::DateUtils;
use Koha::Purresaker;

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

This script calculates and charges overdue fines to patron accounts.  The Koha system preference 'finesMode' controls
whether the fines are calculated and charged to the patron accounts ("Calculate and charge");
calculated and emailed to the admin but not applied ("Calculate (but only for mailing to the admin)"); or not calculated ("Don't calculate").

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
my $finesMode               = C4::Context->preference('finesMode');
my $finesCalendar           = C4::Context->preference('finesCalendar');
my $finesIncludeGracePeriod = C4::Context->preference('FinesIncludeGracePeriod');

my $today = DateTime->now( time_zone => C4::Context->tz() );

my $finesCount    = 0;
my $purresakCount = 0;
#my $overdues = C4::Overdues::Getoverdues();

# C4::Overdues::CalcFine rewritten
sub calcFine {
    my ( $item, $bortype, $branchcode, $datedue, $today  ) = @_;
    my $datedue_clone = $datedue->clone();
    # get issuingrules (fines part will be used)
    my $itemtype = $item->{itemtype} || $item->{itype};
    my $issuing_rule = Koha::IssuingRules->get_effective_issuing_rule({ categorycode => $bortype, itemtype => $itemtype, branchcode => $branchcode });

    return unless $issuing_rule; # If not rule exist, there is no fine
    my ($charge_duration, $units_minus_grace) = (0, 0);
    if ($today > $datedue) {
        if($finesCalendar eq 'noFinesWhenClosed') {
            my $calendar = Koha::Calendar->new( branchcode => $branchcode );
            $charge_duration = $calendar->days_between( $datedue, $today );
        } else {
            $charge_duration = $today->delta_days( $datedue );
        }
        $units_minus_grace = $charge_duration->in_units('days') - $issuing_rule->firstremind;
    }
    my $amount = 0;
    if ( $issuing_rule->chargeperiod && ( $units_minus_grace > 0 ) ) {
        my $units = $finesIncludeGracePeriod ? $charge_duration : $units_minus_grace;
        my $charge_periods = $units / $issuing_rule->chargeperiod;
        # If chargeperiod_charge_at = 1, we charge a fine at the start of each charge period
        # if chargeperiod_charge_at = 0, we charge at the end of each charge period
        $charge_periods = $issuing_rule->chargeperiod_charge_at == 1 ? ceil($charge_periods) : floor($charge_periods);
        $amount = $charge_periods * $issuing_rule->fine;
    } # else { # a zero (or null) chargeperiod or negative units_minus_grace value means no charge. }

    # why return amount = overduefinescap ?
    $amount = $issuing_rule->overduefinescap if $issuing_rule->overduefinescap && $amount > $issuing_rule->overduefinescap;
    $amount = $item->{replacementprice} if ( $issuing_rule->cap_fine_to_replacement_price && $item->{replacementprice} && $amount > $item->{replacementprice} );
    return ($amount, {}, $units_minus_grace, $charge_duration);
}

my %branch_holiday;
my $overdues = Koha::Purresaker->GetPatronOverduesWithPotentialFines();
# Loop each patron with potential fines
while ( my $overdue = $overdues->fetchrow_hashref() ) {
    # skip items lost ? not relevant since we group by borrower, not by issue
    # next if $overdue->{itemlost};

    # get applying circ rules for patron or item
    my $circ_rules_branchcode =
        ( $circControl eq 'ItemHomeLibrary' ) ? $overdue->{itemhomebranch}
      : ( $circControl eq 'PatronLibrary' )   ? $overdue->{borrbranch}
      :                                     $overdue->{branchcode};

    # Add holidays to hashmap if not already added
    if (!$branch_holiday{$circ_rules_branchcode}) {
        my $cal = Koha::Calendar->new( branchcode => $circ_rules_branchcode );
        $branch_holiday{$circ_rules_branchcode} = $cal->is_holiday($today);
    }
    # could group by borrower first, so fine is only applied once
    my $datedue = dt_from_string( $overdue->{date_due} );
    #my ( $amount, $charge_type, $units_minus_grace, $charge_duration ) = C4::Overdues::CalcFine( $overdue, $overdue->{borrcat}, $circ_rules_branchcode, $datedue, $today );
    my ( $amount, $charge_type, $units_minus_grace, $charge_duration ) = calcFine( $overdue, $overdue->{borrcat}, $circ_rules_branchcode, $datedue, $today );
    next if $amount <= 0;
    if (! $branch_holiday{$circ_rules_branchcode}) {
        $verbose and print "Fine: $overdue->{issue_id}, $overdue->{borrowernumber}, $units_minus_grace, $amount\n";
        ++$finesCount;
        my $purresak = Koha::Purresaker->AddOverdue($overdue->{borrowernumber}, $amount);
        $purresakCount += $purresak->rows;
        # NOTE: charge_type is always empty hash
        C4::Overdues::UpdateFine(
            {
                issue_id       => $overdue->{issue_id},
                itemnumber     => $overdue->{itemnumber},
                borrowernumber => $overdue->{borrowernumber},
                amount         => $amount,
                type           => $charge_type,
                due            => output_pref($datedue),
            }
        );
    }
}

if ($verbose) {
    my $overdue_items = $overdues->rows;
    print <<"EOM";
Fines -- $today
Total overdue:    $overdue_items
Fines calculated: $finesCount
Purresaker added: $purresakCount

EOM
}

