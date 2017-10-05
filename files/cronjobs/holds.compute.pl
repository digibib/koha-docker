#!/usr/bin/perl 
use strict;
use warnings;
$|++;
use Data::Dumper;
use Date::Parse;
use DBI;
use JSON; our $JSON = JSON->new()->utf8(1)->pretty(1)->canonical(1); # TODO utf8
use utf8;

# http://github.com/ohait/perl-dbi-sugar.git
use lib 'perl-dbi-sugar/lib';
use DBI::Sugar;
BEGIN {
    # find Koha's Perl modules
    use FindBin;
    eval { require "$FindBin::Bin/usr/share/koha/bin/kohalib.pl" };
}
use C4::Context;
alarm(280);  

my $output = $ARGV[0] or die("missing filename");

DBI::Sugar::factory {
    my $dbh = C4::Context->dbh;
    return $dbh, SELECT_TIME => sub {
        my ($q, $b, $dt) = @_;
        print STDERR Dumper(\@_) if $dt > 0.5;
    };
};


sub category {
    my (%meta) = @_;
    my $mt = $meta{mediatypes};
    my $fmt = $meta{loc_format}; # 090$b
    my $dewey = $meta{loc_dewey}; # 090$c
    my $location = $meta{location}//'';

    if ($mt eq 'Musikkopptak') {
        return 'Annen';
    }
    if ($mt eq 'Film') {
        return 'Annen';
    }
    if ($mt eq 'Spill') {
        return 'Annen';
    }
    if ($mt eq 'Andre') {
        return 'Annen';
    }

    if ($fmt =~ m{^\w*[bu]} or $location =~ m{^(BARNEFAG|UNG|UNGFAG)$}) {
        if ($dewey or $fmt =~ m{E}) {
            return 'Fag barn';
        } else {
            return 'Skjønn barn';
        }
    } else {
        if ($dewey) {
            return 'Fag voksen';
        } else {
            return 'Skjønn voksen';
        }
    }
    warn "unknown category, using Annen: ".Dumper(\%meta)."...";
    return 'Annen';
}

sub compute {
    my ($bnum) = @_;

    my %biblio = SELECT_ROW "* FROM biblio WHERE biblionumber = ?" => [$bnum] or return;

    my %meta = SELECT_ROW q`
        SUBSTRING(ExtractValue(metadata, '//controlfield[@tag="008"]'), 34, 1) AS fiction,
        ExtractValue(metadata, '//datafield[@tag="041"]/subfield[@code="a"]') AS language,
        ExtractValue(metadata, '//datafield[@tag="090"]/subfield[@code="b"]') AS loc_format,
        ExtractValue(metadata, '//datafield[@tag="090"]/subfield[@code="c"]') AS loc_dewey,
        ExtractValue(metadata, '//datafield[@tag="090"]/subfield[@code="d"]') AS loc_location,
        ExtractValue(metadata, '//datafield[@tag="337"]/subfield[@code="a"]') AS mediatypes,
        ExtractValue(metadata, '//datafield[@tag="260"]/subfield[@code="c"][1]') AS pub_year,
        ExtractValue(metadata, '//datafield[@tag="385"]/subfield[@code="a"]') AS audiences
    FROM biblio_metadata WHERE biblionumber = ?` => [$bnum];


    my @items = SELECT "items.*, branchtransfers.tobranch transfer_to FROM items
        LEFT JOIN branchtransfers ON branchtransfers.itemnumber = items.itemnumber AND datearrived IS NULL
        WHERE biblionumber = ?"
    => [$bnum] => sub {
        return \%_;
    };

    my $oldest = 0;
    my @holds = SELECT "biblionumber, reserve_id, branchcode, itemnumber, found, priority, reservedate FROM reserves WHERE biblionumber = ?"
    => [$bnum] => sub {
        my $age = int((time()-str2time($_{reservedate}))/86400);
        $oldest = $age if $age > $oldest;
        return { %_, age => $age, };
    };

    my @pick = sort { $a->{itemnumber} <=> $b->{itemnumber} } _compute(\%biblio, \@items, \@holds);
    return unless @pick;

    my $out = {
        #meta => \%meta,
        dewey => $meta{loc_dewey},
        format => $meta{loc_format},
        sort_author => $meta{loc_location},
        biblionumber => $biblio{biblionumber},
        pub_year => $meta{pub_year},
        title => $biblio{title},    
        author => $biblio{author},
        holds => [],
        age => $oldest,
    };
    for my $pick (@pick) {
        my $loc = $pick->{loc} or die Dumper($pick)."...";
        my $i = {
            itemnumber => $pick->{itemnumber},
            barcode => $pick->{barcode},
            location => $pick->{location},
            itemcallnumber => $pick->{itemcallnumber},
            ccode => $pick->{ccode},
            category => category(%meta, location => $pick->{location}),
        };
        if (exists $pick->{found} or $pick->{transfer_to}) {
            my $b = $out->{enroute}//=[];
            $i->{reserve} = $pick->{reserve} if $pick->{reserve};
            $i->{transfer_to} = $pick->{transfer_to} if $pick->{transfer_to};
            push @$b, $i;
        } else {
            $out->{pick}//={};
            $i->{plukk} = 1;
            my $b = $out->{pick}->{$pick->{loc}}//=[];
            push @$b, $i;
        }
    }
    for my $hold (sort { $a->{priority} <=> $b->{priority} } @holds) {
        push @{$out->{holds}}, {
            reserve_id => $hold->{reserve_id},
            itemnumber => $hold->{itemnumber},
            found => $hold->{found},
            branch => $hold->{branchcode},
            age => $hold->{age},
        };
    }
    return $out;
}

sub _compute {
    my ($bib, $items, $holds) = @_;

    my %orig;
    my %available;
    my %all;
    my %pick;

    my %bybranch;
    my $bybranch = sub {
        my ($code) = @_;
        $code //= 'unknown';
        $bybranch{$code}//={
            code => $code,
            items => 0,
            available => 0,
        };
    };

    for my $item (sort { $a->{itemnumber} <=> $b->{itemnumber} } @$items) {
        my $lastseen = eval { str2time($item->{datelastseen}); };

        my $branch = $item->{homebranch} // 'unknown';
        if ($item->{location} and $item->{location} =~ m{^([a-z]{4})(\.[a-z\d]+)+$}) {
            $branch = $1;
            $item->{loc} = $branch;
            $item->{shelf} = $item->{location};
        } else {
            $item->{loc} = $branch;
            $item->{shelf} = $branch;
        }

        $orig{$item->{itemnumber}} = $item;

        next if $item->{notforloan} or $item->{damaged} or $item->{itemlost};
        next if $item->{itype} and $item->{itype} =~ m{^(DAGSLAAN|UKESLAAN|10DLAAN|TOUKESLAAN|SETT)$};

        $all{$item->{itemnumber}} = $item;

        my $b = $bybranch->($branch);
        $b->{items}++;

        $item->{available}++ if !$item->{onloan};
        if ($item->{available}) {
            $available{$item->{itemnumber}} = $item;
            $b->{available}++;
        }
    }
    for my $hold (sort { $a->{priority} <=> $b->{priority} } @$holds) {
        my $rid = $hold->{reserve_id};
        if (my $i = $hold->{itemnumber}) { # item number is locked
            my $item = $orig{$i} or do {
                warn "Can't find item $i";
                next;
            };
            $item->{reserve} = $rid;
            $item->{found} = $hold->{found};
            $pick{$i} = $item;
            #print "; FIXED $rid $to <= $i $item->{loc}\n";
            $bybranch->($item->{loc})->{available}-- if $item and $item->{loc};
            delete $available{$i};
        }
    }

    for my $hold (sort { $a->{priority} <=> $b->{priority} } @$holds) {
        my $rid = $hold->{reserve_id};
        my $to = $hold->{branchcode};
        my $age = eval { no warnings; str2time($hold->{reservedate}) } // 0;
        $age = int( (time()-$age)/86400) if $age;
        $hold->{age} = $age;
        next if $age < 0; # not active yet (TODO, maybe start working on it 2 days before?)

        if (my $i = $hold->{itemnumber}) { # item number is locked
            next;
        }

        #next if $hold->{found}//'' eq 'W'; # should we check the transfers?
        next if $hold->{found};

        #if ($age>10) { # if there is a hold for 10 days, than all the books should be picked up
        #    print "ALL\n";
        #    return values %all;
        #}
        my $b = $bybranch->($to);
        #print Dumper([branch => $b]);
        if ($b->{available}) {
            my (@list) = grep { $_->{loc} eq $to } values %available;
            if (!@list) {
                $b->{available} = 0; # there were none!
            }
            else {
                $pick{$_->{itemnumber}} = $_ for @list;
                my $first = $list[0];
                delete $all{$first->{itemnumber}};
                $bybranch->($first->{loc})->{available}--;
                #print "; $first->{barcode} for $rid ($to)\n";
                next;
            }
        }
        # no good items found, mark everything for pick
        return values %available;
    }
    return values %pick;
}

my %bnums;
TX {
    SELECT "distinct biblionumber FROM reserves WHERE reservedate < NOW() and found IS NULL ORDER BY biblionumber" => [] => sub { $bnums{$_{biblionumber}}++; };
};
#print "got ".scalar(keys %bnums)." distinct bibnums\n";

my @out;
for my $bnum (sort { $a <=> $b } keys %bnums) {
    TX {
        #printf "; bibnum: %s\n", $bnum;
        #print Dumper(compute($bnum));
        push @out, compute($bnum);


        #for my $pick (@picks) {
            #printf "%s %s (%s)\n", $pick->{barcode}, $pick->{shelf}, $pick->{homebranch};
        #}

        #printf "bibnum: %s\n", $bnum;
        #for my $hold (@holds) {
        #    printf "%16s %4s => %4s %d\n", $hold->{barcode}//'', $hold->{from}//'', $hold->{to}, $hold->{reserve_id};
        #}
        #print "\n";
        #print Dumper({biblionumber => $bnum, holds => \@holds});
    };
}

open my $f, '>', $output or die("can't open output file: $!");
print $f $JSON->encode(\@out);
