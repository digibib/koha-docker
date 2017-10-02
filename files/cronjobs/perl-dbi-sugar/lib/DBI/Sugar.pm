package DBI::Sugar;

use 5.006;
use strict;
use warnings;
use Data::Dumper;

=head1 NAME

DBI::Sugar - Add some sugar to this DBI

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

use base 'Exporter';

our @EXPORT = qw(
   TX
   TX_NEW
   TX_REQUIRED
   SELECT
   SELECT_ROW
   SQL_DO
   INSERT
   UPDATE
   UPSERT
   DELETE
   NEXT_ID
);

=head1 SYNOPSIS

    use DBI::Sugar;

    DBI::Sugar::factory {
        # must return a DBI connection
    };

    # open a new transaction
    TX {
        # select some rows
        my %rows = SELECT "id, a, b FROM myTab WHERE status = ? FOR UPDATE"
        => ['ok'] => sub {
            $_{id} => [$_{a}, $_{b}];
        };

        SQL_DO "DELETE FROM myTab ORDER BY id ASC LIMIT ?" => [1];

        INSERT myTab => {
            a => "Foo",
            b => "Bar",
        };
    };
    # commit if it returns, rollback if it dies

=head1 DESCRIPTION

=head2 SELECT {...}

How to quickly get data from DB and trasform it:

    my @AoH = SELECT "* FROM myTable" => [] => sub { \%_ };

    my @AoA = SELECT "* FROM myTable" => [] => sub { \@_ };

    my %HoA = SELECT "* FROM myTable" => [] => sub { $_{id} => \@_ };

    my %h = SELECT "key, value FROM myTable" => [] => sub { @_ };


=head2 A Micro Connection Pooler

    my @conns;
    DBI::Sugar::factory {
        my $dbh = shift(@conns) // DBI->connect('dbi:mysql:oha', 'oha', undef, {
                RaiseError => 1,
            });
        return $dbh,
        release => sub {
            push @conns, $dbh;
        };
    };

=head2 A slightly better Micro Connection Pooler

    my @conns;
    DBI::Sugar::factory {
        my $slot = shift @conns;
        $slot //= do {
            my $dbh = DBI->connect('dbi:mysql:oha', 'oha', undef, {
                    RaiseError => 1,
                });
            [$dbh, 0];
        };
        $slot->[1]++;
        return $slot->[0],
        commit => sub {
            $slot->[1]<3 and push @conns, $slot;
        };
    };

=head1 METHODS

=head2 factory

    DBI::Sugar::factory {
        return $dbh;
    };

set the connection factory that will be used by TX

it's possible to add handlers for when the connection will be released:

    DBI::Sugar::factory {
        return $dbh,
            release => sub { ... },
    };

    DBI::Sugar::factory {
        return $dbh,
            commit => sub { ... },
            rollback => sub { ... },
    };

when a commit happen, the C<commit> sub or the C<release> sub is invoked. similarly for rollback

=cut

our $FACTORY;
our $DBH;
our $PID = $$;
our %OPTS;

sub factory(&) {
    ($FACTORY) = @_;
}

sub pool(&%) {
    my ($factory, %opts)  = @_;

    my @slots;
    my $pid = $$;
    my $max_age = $opts{max_age} // die "you must specify a {max_age}";
    my $max_uses = $opts{max_uses} // die "you must specify a {max_uses}";
    $FACTORY = sub {
        my $slot;
        if ($pid != $$) {
            @slots = (); # pool will be recreated
        }
        while (my $s = shift @slots)
        {
            next if $s->{created} < time()-$max_age;
            $slot = $s;
            last;
        }

        $slot //= {
            dbh => $factory->(),
            created => time(),
            uses => 0,
            pid => $$,
        };
        $slot->{uses}++;

        return $slot->{dbh},
            commit => sub {
                push @slots, $slot if $slot->{uses} < $max_uses;
            };
    };
}

sub _make() {
    $FACTORY or die "you must set DBI::Sugar::factory { ... } first";
    ($DBH, %OPTS) = $FACTORY->();
    $DBH or die "factory returned a null connection";
    $DBH->{Active} or die "factory returned a non-active connection";
    #print "[$$] _make() => $DBH ($DBH->{AutoCommit})\n";
    $OPTS{commit} //= $OPTS{release} // sub {};
    $OPTS{rollback} //= $OPTS{release} // sub {}
}

=head2 dbh

    my $dbh = DBI::Sugar::dbh();

return the current DBH (as in, the one in the current transaction, that
would be used by the next statement)

=cut

sub dbh() {
    $DBH;
}

=head1 EXPORT

=head2 TX

a transaction block, with a defined connection to the database.

the code will be executed, and if returns normally, the transaction will be committed.

if the code dies, then the transaction is rollbacked and the error is "rethrown"

=cut

=head2 TX, TX_NEW

    TX { ... };
    TX_NEW { ... };

retrieve a DBH using the factory, and open a transaction (begin_work) on it.

the execute the given code. if the code returns the transaction is committed.

if the code dies, then the transaction is rollbacked and the error is rethrown.

At this moment, it's mandatory to have an open transaction, otherwise any db operations
will fail.

The only difference from C<TX> and C<TX_NEW> is that TX will die if already in a transaction.

Note: normally, for TX_NEW to work properly, a different DBH is required, and so the factory
you provided should handle this.

TODO: consider to use savepoints if the database allows it.

=head TX_REQUIRED

    TX_REQUIRED;

dies there is no transaction. Useful to die earlier than executing a statement.

=cut

sub TX_REQUIRED() {
    $DBH or die "not in a transaction";
}

sub TX(&) {
    _tx(@_);
}

sub _TX {
    #$DBH and die "already in a transaction";
    _tx(@_);
}

sub TX_NEW(&) {
    local $DBH;
    local %OPTS;
    _tx(@_);
}


sub _tx {
    my ($code) = @_;

    if ($DBH) {
        $PID == $$ or die "forked?";
        return $code->();
    }

    local $DBH = $DBH;
    local $PID = $$;
    local %OPTS = %OPTS;
    _make();
    $PID = $$;

    #print gmtime()." [$$] BEGIN $DBH ($DBH->{AutoCommit})\n";
    $DBH->begin_work();
    my @out;
    my $wa = wantarray;
    my $ok = eval {
        if ($wa) {
            @out = $code->();
        } elsif(defined $wa) {
            $out[0] = $code->(); 
        } else {
            $code->();
        }
        1;
    };
    my $err = $@;

    if ($ok) {
        #print gmtime()." [$$] COMMIT $DBH\n";
        $DBH->commit();
        $OPTS{commit}->();
        if ($wa) {
            return @out;
        } else {
            return $out[0];
        }
    }
    else {
        #print gmtime()." [$$] ROLLBACK $DBH\n";
        $DBH->rollback();
        $OPTS{rollback}->();
        die $err;
    }
}

=head2 SELECT

    SELECT "field1, field2 FROM tab WHERE cond = ?" => [$cond] => sub {
        ...
    };

performs a select on the database. the query string is passed as is, only prepending C<"SELECT "> at
the beginning.

the rowset will be available in the code block both as @_ and %_ (for the latter, the key will be the
column name)

the result of the code block is returned as in a C<map { ... }>


Note: "SELECT " is prepended to the queries automatically.


=head3 why a map-like?

Databases drivers are designed to return data while fetching more on the backend. On some databases you
can even specify to the optimizer you want the first row as fast as possible, instead of being fast
to fetch all the data.

It's generally better then to just use the data while fetched, instead of fetching the whole data first
and then iterating over it.

Normally, while using DBI, you will end up writing code like:

    my $sth = $dbh->prepare("SELECT "col1, col2, col3, col4
        FROM tab1 LEFT JOIN tab2 ON tab1.left = tab2.right
        WHERE type = ? AND x > ? AND x < ?");
    $sth->execute($type, $min, $max);
    while(my $row = $sth->fetchrows_hashref()) {
        IMPORTANT STUFF HERE
    }
    $sth->finish

Using DBI::Sugar it will become:

    SELECT "col1, col2, col3, col4
        FROM tab1 LEFT JOIN tab2 ON tab1.left = tab2.right
        WHERE type = ? AND x > ? AND x < ?"
    => [$type, $min, $max]
    => sub {
        IMPORTANT STUFF HERE
    }


=cut

sub SELECT($$&) {
    _SELECT(@_, sub {});
}

sub _SELECT {
    my ($query, $binds, $code, $hook) = @_;
    $PID == $$ or die "forked?";
    $query =~ s{\s+}{ }g;

    my @caller = caller(1);
    my $stm = "-- DBI::Sugar::SELECT() at $caller[1]:$caller[2]\nSELECT $query";

    $DBH or die "not in a transaction";

    my $sth = $DBH->prepare($stm);
    $sth->execute(@$binds) or die "what!: $! ".$DBH::errstr;
    my @out;
    my @NAMES = @{$sth->{NAME}//[]};

    while(my $row = $sth->fetchrow_arrayref) {
        $hook->($row, $sth, $DBH);
        my @v = @$row;
        my $i = 0;
        local %_ = map { $_ => $v[$i++] } @NAMES;
        local $_ = $row;
        if (wantarray) {
            push @out, $code->(@v);
        } else {
            $code->(@v);
            $out[0] = ($out[0]//0) +1;
        }
    }
    $sth->finish;
    if (wantarray) {
        return @out;
    } else {
        return $out[0];
    }
}

=head2 SELECT_ROW

    my %row = SELECT_ROW "* FROM myTable WHERE id = ?" => [$id];

fetch a single row from the database, and returns it as an hash

if no rows are found, the hash will be empty

IMPORTANT: it will die if more than one rows are found.

=cut

sub SELECT_ROW($$) {
    my ($stm, $binds) = @_;
    my $out;
    _SELECT($stm, $binds, sub {
            die "expected 1 row, got more: $stm" if $out;
            $out = {%_};
        }, sub {});
    return $out ? %$out : ();
}

sub _SELECT_ROW {
    my ($stm, $binds, $hook) = @_;
    $PID == $$ or die "forked?";
    my $out;
    _SELECT($stm, $binds, sub {
            die "expected 1 row, got more: $stm" if $out;
            $out = {%_};
        }, $hook);
    return $out ? %$out : ();
}

=head2 SQL_DO

    SQL_DO "UPDATE myTable SET x=x+?" => [1];

execute a statement and return

=cut

sub SQL_DO($$) {
    my ($query, $binds) = @_;

    my @caller = caller(); my $stm = "-- DBI::Sugar::SQL_DO() at $caller[1]:$caller[2]\n$query";

    $DBH or die "not in a transaction";

    my $sth = $DBH->prepare($stm);
    return $sth->execute(@$binds);
}


=head2 INSERT

    INSERT myTable => {
        id => $id,
        col1 => $col1,
        col2 => $col2,
    };

Insert into the given table, the given data;

=cut

sub INSERT($$) {
    my ($tab, $data) = @_;
    $PID == $$ or die "forked?";

    my @caller = caller(); my $stm = "-- DBI::Sugar::INSERT() at $caller[1]:$caller[2]\n";

    $DBH or die "not in a transaction";

    my @cols;
    my @placeholders;
    my @binds;
    for my $key (keys %$data) {
        my $val = $data->{$key};
        if ("ARRAY" eq ref $val) {
            my ($p, @v) = @$val;
            push @cols, "`$key`";
            push @placeholders, $p;
            push @binds, @v;
        } else {
            push @cols, "`$key`";
            push @placeholders, '?';
            push @binds, $val;
        }
    }
    @cols or die "you must specify at least one field";
    $stm .= "INSERT INTO $tab (".
        join(', ', @cols).") VALUES (".
        join(', ', @placeholders).")";

    my $sth = $DBH->prepare($stm);
    return $sth->execute(@binds);
}

=head2 UPDATE

    UPDATE myTable => {
        domain => $domain,
        port => $port,
    } => {
        name => $name,
        ct => ['ct+?', $y],
    };

The above will be converted in

    UPDATE myTable SET name = ?, ct = ct+? WHERE domain = ? AND port = ?

Note: conditions are always joined in AND, for complex conditions use a SQL_DO

=cut

sub UPDATE($$$) {
    my ($tab, $where, $set) = @_;
    $PID == $$ or die "forked?";

    my @caller = caller(); my $stm = "-- DBI::Sugar::UPDATE() at $caller[1]:$caller[2]\n";

    $DBH or die "not in a transaction";

    my @sets;
    my @conds;
    my @binds;

    for my $k (keys %$set) {
        my $v = $set->{$k};
        if (ref $v) {
            my ($l, @r);
            eval { ($l, @r) = @$v; 1 } or die "can't use '$v' as a value: ".Dumper($v);
            push @sets, "`$k` = $l";
            push @binds, @r;
        } else {
            push @sets, "`$k` = ?";
            push @binds, $v;
        }
    }

    for my $k (keys %$where) {
        my $v = $where->{$k};
        push @conds, "`$k` = ?";
        push @binds, $v;
    }

    $stm .= "UPDATE $tab SET ".join(', ', @sets);
    $stm .= " WHERE ".join(' AND ', @conds) if @conds;

    my $sth = $DBH->prepare($stm);
    my $ct = 0+$sth->execute(@binds);
    #printf "DBG [%d], rows: %d\n", $ct, $sth->rows;
    return $ct;
}


=head2 DELETE

    DELETE myTable => {
        status => 'to_delete',
    };

=cut

sub DELETE($$) {
    my ($tab, $where) = @_;

    $PID == $$ or die "forked?";

    my @caller = caller(); my $stm = "-- DBI::Sugar::DELETE() at $caller[1]:$caller[2]\n";

    $DBH or die "not in a transaction";

    my @conds;
    my @binds;

    for my $k (keys %$where) {
        my $v = $where->{$k};
        push @conds, "$k = ?";
        push @binds, $v;
    }

    $stm .= "DELETE FROM $tab WHERE ".join(' AND ', @conds);

    my $sth = $DBH->prepare($stm);
    my $ct = 0+$sth->execute(@binds);
    return $ct;
}


=head2 UPSERT

    UPSERT myTable => {
        id => $id,
    } => {
        count => ['count + ?', 1],
        last_mod => ['NOW()'],
    } => {
        count => 1, # override
        created => ['NOW()'],
        # id and last_mod are set as above
    };

it performs and update, and if it fails (no rows changed) performs an insert

the insert will have all the fields set in the update where condition, overriden
by the set, and then again overriden by the last block.

it _might_ takes advantage of DBMS specific functions

return the number of rows changed by the update (which means 0 if it performs an insert)

=cut

sub UPSERT($$$$) {
    my ($tab, $where, $set, $insert) = @_;
    $PID == $$ or die "forked?";
    my $ct = UPDATE($tab, $where, $set);
    $ct or INSERT($tab, {%$where, %$set, %$insert});
    return $ct;
}

=head2 NEXT_ID

    use DBI::SUGAR qw/:DEFAULT NEXT_ID/; # not exported by default

    # Optionally, you can change the defaults:
    Next_ID_settings(
        "ids", # the name of the table which contains the ids
        "name", # the name of the field which contains the id names
        "next", # the name of the field which contains the next id
        );
    # this will likely requires you to do something like:
    # CREATE TABLE ids (name VARCHAR(256), next INTEGER, PRIMARY KEY (name));

    my $next_id = NEXT_ID myName => 5;

It first checks if an ID is already available in the "pool" for the given name, and returns it.

Otherwise it creates a new TX, lock the table, fetches the next id from the table, updates the
table adding 5 and returns the next, storing the extra ids in the pool for later use

It is important to note that all this happens in a TX_NEW block! You don't have to do anything,
just be aware a nested transaction takes place. which means that even if the
caller die and ROLLBACK, the changes on the id table are committed and won't clases with other
transactions (they will be wasted)

=cut

our $NEXT_ID_CONF = {
    next => {},
    table => "ids",
    name_field => "name",
    next_field => "next",
};

sub NEXT_ID_settings {
    my @out = map { $NEXT_ID_CONF->{$_} } qw/table name_field next_field/;
    if (@_) {
        my ($table, $name, $next) = @_;
        $table =~ m{^\w+$} or die "invalid table name: '$table'";
        $name =~ m{^\w+$} or die "invalid name field: '$name'";
        $next =~ m{^\w+$} or die "invalid next field: '$next'";
        $NEXT_ID_CONF->{table} = $table;
        $NEXT_ID_CONF->{name_field} = $name;
        $NEXT_ID_CONF->{next_field} = $next;
    };
    return @out;
};

sub NEXT_ID($$) {
    my ($name, $size) = @_;
    $size > 0 or die "invalid size: $size";
    my $table = $NEXT_ID_CONF->{table};
    my $ids = $NEXT_ID_CONF->{next}->{$table} //= {};

    my $pool = $ids->{$name} //=
    TX_NEW {
        # fetching a new id should NOT be rollbackable, since other tx might need a new one in the meanwhile
        # if a rollback occour, the id fetched will be lost.
        # this also play well with banking extra ids
        my $name_field = $NEXT_ID_CONF->{name_field};
        my $next_field = $NEXT_ID_CONF->{next_field};

        my (undef, $next) = SELECT_ROW "$next_field AS next FROM $table WHERE $name_field = ?" => [$name];

        if ($next) {
            UPDATE $table => {
                $name_field => $name,
            } => {
                $next_field => $next + $size,
            }
        } else {
            $next = 1;
            INSERT $table => {
                $name_field => $name,
                $next_field => $next + $size,
            };
        }

        return {
            next => $next,
            left => $size,
        };
    };

    my $next = $pool->{next};

    --$pool->{left} and $pool->{next}++
        or delete $ids->{$name};

    return $next;
}

=head1 AUTHOR

Francesco Rivetti, C<< <oha at oha.it> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-dbi-sugar at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DBI-Sugar>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBI::Sugar

You can also look for information at:

=over 4

=item * GitHub

L<http://github.com/ohait/perl-dbi-sugar>

=back


=head1 ACKNOWLEDGEMENTS

Tadeusz 'tadzik' Sosnierz - to convince me to release this module

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Francesco Rivetti.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of DBI::Sugar
