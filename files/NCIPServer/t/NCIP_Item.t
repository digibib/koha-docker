#/usr/bin/perl

use strict;
use warnings;
use lib 'lib';

use Test::More tests => 3;                      # last test to print

use_ok('NCIP::Item');

ok(my $user = NCIP::Item->new({itemid => 1}),'Create a new item object');
is($user->itemid(), '1', "Test getting itemid");

