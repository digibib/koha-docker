#/usr/bin/perl

use strict;
use warnings;
use lib 'lib';

use Test::More tests => 4;                      # last test to print

use_ok('NCIP::User');

ok(my $user = NCIP::User->new(),'Create a new user object');
ok($user->firstname('Chris'),'Set firstname');
is($user->firstname(), 'Chris', "Test our getting");

