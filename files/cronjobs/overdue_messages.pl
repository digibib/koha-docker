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
use Koha::Patron::Debarments qw(AddUniqueDebarment);

use C4::Log qw( cronlogaction );
use Template;
use utf8;
binmode( STDOUT, ":utf8" );

use Getopt::Long;

my $help;
my ($verbose, $test_mode) = (0,0);
my $tt = Template->new({ENCODING => 'utf8'});

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
    -t --test:      test mode, don't debar or send messages

ENDUSAGE

if ($help) {
    print $usage;
    exit;
}

cronlogaction();

my $templates = {
    "ODUE V2" => {
        title   => "ODUEV2: 2. purring på forfalte lån",
        content => <<"EOF",
Hei [% patron.firstname %].

Du har lån som skulle vært levert :
[% FOREACH o IN overdues %]
    [% o.title %], [% o.author %] [% o.barcode %]
[% END %]

Levér så fort du kan. Det er flere som kan ha lyst til å låne det du har lånt.
Hvis ikke materialet blir levert, vil du motta et erstatningskrav fra Oslo kemnerkontor.

Hilsen
Deichman
EOF
    },
    "ODUE BARN" => {
        title => "ODUEBARN: 2. purring på forfalte lån",
        content => <<"EOF",
Hei [% patron.firstname %].

Du har lånt noe hos oss som du skulle ha levert for 10 dager siden. Det vi savner er:
[% FOREACH o IN overdues %]
    [% o.title %], [% o.author %] [% o.barcode %]
[% END %]

Du kan ikke låne noe mer før vi får dette tilbake. Levér så fort du kan. Det er flere som kan ha lyst til å låne det du har lånt.
Hvis du ikke leverer tilbake, vil du få et erstatningskrav fra Oslo Kemnerkontor.

Hilsen
Deichman
EOF
    },
    "ODUE INST" => {
        title => "ODUEINST: 2. purring på forfalte lån",
        content => <<"EOF",
Hei [% patron.lastname %].

Lånekortnummer: [% patron.cardnumber %]

Følgende lån forfalt for 5 dager siden:
[% FOREACH o IN overdues %]
    [% o.title %], [% o.author %] [% o.barcode %]
[% END %]

Vi ber deg levere tilbake til oss snarest.

Husk at du fortsatt kan forlenge lånet på Mine Sider. Ikke ferdig? Hurtiglån, dagslån, lån som er reseververt av andre, eller lån som allerede er forlenget to ganger kan ikke fornyes.

Med vennlig hilsen
Deichman
EOF
    },
    "ODUE FJERNLAAN 2" => {
        title => "ODUEILL: 2. purring på forfalte lån",
        content => <<"EOF",
Hei [% patron.lastname %].

Lånekortnummer: [% patron.cardnumber %]

Følgende lån forfalt for 15 dager siden:
[% FOREACH o IN overdues %]
    [% o.title %], [% o.author %] [% o.barcode %]
[% END %]

Du kan prøve å forlenge lånene dine på Mine sider https://sok.deichman.no/profile
Lån som allerede er forlenget 3 ganger eller reservert av andre, kan ikke forlenges. For materiale som ikke blir levert vil du motta et erstatningskrav fra Oslo kemnerkontor.

Med vennlig hilsen
Deichman
EOF
    },
    "ODUE SKOLE 2" => {
        title => "ODUESKOLE2: 2. purring på forfalte lån",
        content => <<"EOF",
Hei [% patron.firstname %] [% patron.surname %],
Lånekortnummer: [% patron.cardnumber %]

Vi kan ikke se å ha mottatt dine lån fra skoletjenesten med leveringsfrist [% overdues.0.date_due %]
Dette er 2. purring.
Et erstatningskrav vil bli sendt til skolen dersom materialet ikke blir levert innen kort tid.

[% FOREACH o IN overdues %]
    [% o.title %], [% o.author %] [% o.barcode %]
[% END %]

Vennligst kontakt oss dersom noe er uklart.
https://hjelp.deichman.no/hc/no/requests/new

Med vennlig hilsen
Deichmanske bibliotek, skoletjenesten
Telefon:  23 43 29 00 (mandag – fredag, kl.12:00 – 15:30)
EOF
    },
    "ODUE BIB" => {
        title => "ODUEBIB: Melding om forfall",
        content => <<"EOF",
Hei [% patron.firstname %],
Lånekortnummer: [% patron.cardnumber %]

Følgende lån forfalt for 5 dager siden:

[% FOREACH o IN overdues %]
    [% o.title %], [% o.author %] [% o.barcode %]
[% END %]

Vi ber deg levere tilbake til oss snarest.

Med vennlig hilsen
Deichman
EOF
    }
};

# SYSPREFS
my $circControl  = C4::Context->preference('CircControl');
my $from_address = C4::Context->preference('KohaAdminEmailAddress');

my $today = DateTime->now( time_zone => C4::Context->tz() );

my ($totalOverdues,$triggeredOverdues,$smsMessagesSent,$emailMessagesSent,$printMessagesSent, $patronsDebarred) = (0,0,0,0,0,0);

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
            my $trigger = grep { $_->{days_overdue} == 29} @{$overdues};
            if ($trigger) {
                ++$triggeredOverdues;
                # Send message
                # choose correct transport, and send only _one_ notice, mail first, sms second?
                my $transport;
                my $transports = $rule->{"letter$i"}->{transports};
                #warn Dumper($transports);
                # Not used?
                #my $patron_message_prefs  = C4::Members::Messaging::GetMessagingPreferences({ borrowernumber => $patron->{borrowernumber}, message_name => 'Item_Due' });

                if ( $patron->{borremail} && grep /^email$/, @{$transports} ) {
                    $transport = "email";
                    ++$emailMessagesSent;
                } elsif ($patron->{borrsms} && grep /^sms$/, @{$transports} ) {
                    $transport = "sms";
                    ++$smsMessagesSent;
                } else {
                    $transport = "print";
                    ++$printMessagesSent
                }
                warn $letter;
                #my $template = C4::Letters::getletter("circulation", $letter, $rule->{branchcode}, $transport);
                my $template = $templates->{$letter}; # TODO: swap with above when ready
                $template or warn "Letter $letter not found";
                $template and sendPatronMessage($template, $transport, $patron, $overdues);
                $rule->{"letter$i"}->{debar} and debarPatron($patron);
                next PATRON;
            }
        }
    }
}

sub sendPatronMessage {
    my ($template, $transport, $patron, $overdues) = @_;
    my $content = generate_letter_content($template, $patron, $overdues);
    $verbose and print $content;

    my %letter = (
        title => $template->{title},
        content => $content,
    );
    $test_mode or C4::Letters::EnqueueLetter({
        letter                 => \%letter,
        borrowernumber         => $patron->{borrowernumber},
        message_transport_type => $transport,
        from_address           => $from_address,
        to_address             => $patron->{email},
    });
}

sub generate_letter_content {
  my ( $template, $patron, $overdues ) = @_;
  my $processed_content = '';
  $tt->process(\$template->{content}, { patron => $patron, overdues => $overdues }, \$processed_content, {binmode => ':utf8'}) || die $tt->error;
  return $processed_content;
}

sub debarPatron {
    my $patron = shift;
    $test_mode or Koha::Patron::Debarments::AddUniqueDebarment({
        borrowernumber => $patron->{borrowernumber},
        type           => 'OVERDUES',
        comment => "OVERDUES_PROCESS " .  _today(),
    });
    $verbose and warn "debarring patron $patron->{borrowernumber}\n";
    ++$patronsDebarred;
}

sub _today {
    return DateTime->now()->strftime('%d.%m.%Y');
}

my $patronsWithOverdues = $patrons->rows;
$test_mode and print "TEST MODE\n";
print <<"EOM";
Overdues Cronjob -- $today
Total overdues:         $totalOverdues
Patrons with overdues:  $patronsWithOverdues
Triggered overdues:     $triggeredOverdues
SMS messages sent:      $smsMessagesSent
Email messages sent:    $emailMessagesSent
Print messages sent:    $printMessagesSent
Patrons debarred:       $patronsDebarred

EOM
