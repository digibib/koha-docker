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

use C4::Context;
use C4::Letters;
use Template;

use C4::Log qw( cronlogaction );
use utf8;

# http://github.com/ohait/perl-dbi-sugar.git
use lib 'perl-dbi-sugar/lib';
use DBI::Sugar;
use Getopt::Long;

my $from_address = C4::Context->preference('KohaAdminEmailAddress');
my $lettercode = 'HOLD_REMINDER';
my $tt = Template->new;

my ( $days, $mtt, $verbose );
GetOptions(
    'days=s'        => \$days     || '4',     # days since waiting
    'mtt=s'         => \$mtt      || 'email', # message transport
    'v|verbose'     => \$verbose,             # verbose output
);

DBI::Sugar::factory {
 my $dbh = C4::Context->dbh();
 return $dbh;
};

# Borrowers with pickups in waiting for 4 days (after waitingdate)
my $reservesByPatrons;
TX {
  my @reserves = SELECT "b.*, r.*, i.barcode, bib.*
    FROM reserves r
    JOIN borrowers b USING(borrowernumber)
    JOIN items i USING(itemnumber)
    JOIN biblio bib ON (bib.biblionumber=r.biblionumber)
    WHERE r.found = 'W'
    AND b.categorycode IN ('B', 'V')
    AND TO_DAYS(NOW())-TO_DAYS(r.waitingdate) = ? LIMIT 50" => [$days] => sub {
      return \%_;
    };
  $reservesByPatrons = groupByPatrons(\@reserves);
};

my $template = <<EOF;
Heisann [% meta.firstname %]!
Lånernummer: [% meta.cardnumber %]

Du har fortsatt ting til avhenting:
[% FOREACH item IN items %]
  [% item.author %]: [% item.title %] - hentenummer: [% item.pickupnumber %] - hentefrist [% item.expirationdate %]
[% END %]
Vennlig hilsen
Deichmanske bibliotek
EOF

# Now loop patrons and compose digest email
while(my($k, $v) = each %{$reservesByPatrons}) {
  next unless $v->[0]->{email};
  my %meta = (
    borrowernumber => $k,
    cardnumber     => $v->[0]->{cardnumber},
    email          => $v->[0]->{email},
    surname        => $v->[0]->{surname},
    firstname      => $v->[0]->{firstname},
  );

  my $notice = generate_reminder_notice({ meta => \%meta, items => $v });
  $verbose && print $notice;

  my %letter = (
    title => "Påminnelse om ting til avhenting",
    content => $notice,
  );

  # put letter in message_queue
  C4::Letters::EnqueueLetter(
      {   letter                 => \%letter,
          borrowernumber         => $meta{borrowernumber},
          message_transport_type => 'email',
          from_address           => $from_address,
          to_address             => $meta{email},
      }
  );
}

$verbose && print "\n\nSUMMARY: Patrons Notified:\t " . scalar (keys %{$reservesByPatrons}) . "\n";

sub generate_reminder_notice {
  my ( $params ) = @_;
  my $notice = '';
  $tt->process(\$template, { meta => $params->{meta}, items => $params->{items} }, \$notice) || die $tt->error;
  return $notice;
}

sub groupByPatrons {
  my $reserves = shift;
  my %grouped;
  for (@{$reserves} ) {
     push @{ $grouped{$_->{borrowernumber}} }, $_;
  }
  return \%grouped;
}
