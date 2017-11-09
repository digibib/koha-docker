#!/usr/bin/perl -w
#
# cronjob: holds_reminder.pl
# This job sends holds reminders to patrons that have pending pickups
#   using HOLD_REMINDER template if 4 days spent since reserve set waiting (waitingdate - 4 days)
#   AND reserve is still 'W'
use Modern::Perl;
use strict;
use warnings;

BEGIN {
    # find Koha's Perl modules
    use FindBin;
    eval { require "$FindBin::Bin/usr/share/koha/bin/kohalib.pl" };
}

use C4::Members::Messaging;
use C4::Context;
use C4::Letters;
use Template;

use C4::Log qw( cronlogaction );
use utf8;
binmode( STDOUT, ":utf8" );

use Getopt::Long;

my $from_address = C4::Context->preference('KohaAdminEmailAddress');
my $tt = Template->new({ENCODING => 'utf8'});

my $days = 4;
my ( $verbose, $test );
GetOptions(
    'd|days=s'      => \$days,    # days since waiting
    'v|verbose'     => \$verbose, # verbose output
    't|test'        => \$test,    # don't send messages, just print results
);

my $dbh = C4::Context->dbh();
my $query = "SELECT b.*, bib.title, br.branchname, r.pickupnumber,
      DATE_FORMAT(r.expirationdate, '%d.%m.%Y') AS expdate
    FROM reserves r
    JOIN borrowers b USING(borrowernumber)
    JOIN biblio bib ON (bib.biblionumber=r.biblionumber)
    JOIN branches br ON (br.branchcode=r.branchcode)
    WHERE r.found = 'W'
    AND b.categorycode IN ('B', 'V')
    AND TO_DAYS(NOW())-TO_DAYS(r.waitingdate) = ? LIMIT 50";
my $sth = C4::Context->dbh->prepare($query);
$sth->execute($days) or die "Error running query: $sth";

my $template = <<EOF;
Hei [% result.firstname %]!
Vi vil bare minne deg på å hente "[% result.title %]" på [% result.branchname %] innen hentefristen, som er [% result.expdate %].

Hentenummer er [% result.pickupnumber %].

Lån gjerne mer når du er innom!
Mvh. Deichmanske bibliotek
EOF

my $sms = 0;
my $email = 0;

# Now loop reserves and compose email
while ( my $res = $sth->fetchrow_hashref() ) {
  next unless $res->{email} || $res->{smsalertnumber};
  # TODO: get messageprefs in previous query?
  my $mtp = C4::Members::Messaging::GetMessagingPreferences( { borrowernumber => $res->{borrowernumber}, message_name => 'Hold_Filled' } )->{transports};
  next unless $mtp;
  if ($mtp->{sms} && $res->{smsalertnumber}) { # patron wants hold sms and has smsalertnumber
    $res->{preferred_mtt} = "sms";
    $sms++;
  } elsif ($mtp->{email} && $res->{email}) {   # patron wants hold email and has email
    $res->{preferred_mtt} = "email";
    $email++;
  } else {
    next;
  }

  my $notice = generate_reminder_notice({ result => $res });
  $verbose && print $notice;

  my %letter = (
    title => "Påminnelse om ting til avhenting",
    content => $notice,
  );

  # put letter in message_queue
  unless ($test) {
    C4::Letters::EnqueueLetter(
        {   letter                 => \%letter,
            borrowernumber         => $res->{borrowernumber},
            message_transport_type => $res->{preferred_mtt},
            from_address           => $from_address,
            to_address             => $res->{email},
        }
    );
  }
}

print "\n\nHOLDS REMINDER SUMMARY:\nSMS hold reminders sent:\t$sms\nEmail hold reminders sent:\t$email\n";

sub generate_reminder_notice {
  my ( $params ) = @_;
  my $notice = '';
  $tt->process(\$template, { result => $params->{result} }, \$notice, {binmode => ':utf8'}) || die $tt->error;
  return $notice;
}
