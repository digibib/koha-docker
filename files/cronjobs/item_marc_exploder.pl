use strict;
use warnings;

use utf8;
binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

# create table biblio_marc_tags (biblionumber int, tag varchar(32), value varchar(200));
# create index biblio_marc_tags_idx on biblio_marc_tags(biblionumber, tag);
# create index biblio_marc_tags_idx2 on biblio_marc_tags(tag, value);

# OPTIONAL:
# create view biblio_view as select *,
#   (SELECT value FROM biblio_marc_tags t WHERE t.biblionumber = b.biblionumber AND tag = '337a') as 337a,
#   (SELECT value FROM biblio_marc_tags t WHERE t.biblionumber = b.biblionumber AND tag = '385a') as 385a
# FROM biblio b;

# NOTE: be sure there is an index on biblio_metadata(timestamp)

# to run as a incremental cron every minute: --age=70 --ttl=50
# this means to fetch changes up to 70 seconds old, and abort if it takes longer than 50 seconds
# add 60 to both for each minute of wait in the cron, so --age=130 -ttl=110 if cron is every 2 minutes.

use DBI;
use Data::Dumper;
use XML::LibXML; our $XML = XML::LibXML->new();

use Getopt::Long;
my $driver = 'mysql';
my $host = '';
my $db = '';
my $user = undef;
my $pass = undef;
my $age = 0;
my $ttl = 0;
my $dbg = 0;
GetOptions(
    "host=s" => \$host,
    "db=s"   => \$db,
    "user=s" => \$user,
    "pass=s" => \$pass,
    "age=i"  => \$age,
    "ttl=i"  => \$ttl,
    "dbi=s" => \$driver,
    "v" => \$dbg,
) or die "Usage: $0 --db=DB_NAME (--host=DB_HOST) (--age=70 --ttl=40)\n";

my $expire = $ttl ? time() + $ttl : 0;

my $dbh = DBI->connect(
    "dbi:$driver:$db".($host?";hostname=$host":""), $user, $pass, {
        RaiseError => 1,
        mysql_enable_utf8mb4 => 1,
        mysql_enable_utf8 => 1,
    },
);
#$dbh->{mysql_use_result} = 1; # force using data while it's coming, instead of storing the whole results (WARN: this makes sth non-reentrant)

sub DELETE_tags {
    my ($biblionum) = @_;
    my $sth = $dbh->prepare('DELETE FROM biblio_marc_tags WHERE biblionumber = ?');
    $sth->execute($biblionum);
}

sub INSERT_tag {
    my ($biblionum, $key, $value) = @_;
    my $sth = $dbh->prepare('INSERT INTO biblio_marc_tags (biblionumber, tag, value) VALUES (?,?,?)');
    $sth->execute($biblionum, $key, $value);
}

my $query = "SELECT * FROM biblio_metadata";
$age and $query .= " WHERE timestamp > NOW() - INTERVAL $age SECOND";
$dbg and print STDERR "$query\n";

my $sth = $dbh->prepare($query);

$sth->execute();

while(my $row = $sth->fetchrow_hashref) {
    die "script running for too long, aborting." if $expire and time() > $expire;

    my $mflav = $row->{marcflavour};
    my $biblionum = $row->{biblionumber};
    if ($mflav eq 'MARC21') {
        $dbg and print STDERR "$biblionum $mflav\n";
        $dbh->begin_work();
        DELETE_tags ($biblionum);
        my $xml = $XML->parse_string($row->{metadata});
        for my $field ($xml->findnodes("//*[name()='controlfield']")) {
            my $tag = $field->getAttribute('tag');
            if ($tag eq '008') {
                my $value = $field->textContent();
                INSERT_tag($biblionum, "008", $value);
                $value =~ m{^.................................([01])} and INSERT_tag($biblionum, "008x", $1);
            }
        }
        for my $field ($xml->findnodes("//*[name()='datafield']")) {
            my $tag = $field->getAttribute('tag');
            for my $s ($field->findnodes("*")) {
                my $code = $s->getAttribute('code') or next;
                my $value = $s->textContent();
                INSERT_tag($biblionum, "$tag$code", $value);
            }
        }
        $dbh->commit();
    } else {
        warn "invalid marcflavour: $mflav (biblionum: $biblionum)";
    }
}

