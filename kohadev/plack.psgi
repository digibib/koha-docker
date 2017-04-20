#!/usr/bin/perl

# This file is part of Koha.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Modern::Perl;

use lib("/kohadev/kohaclone");
use lib("/kohadev/kohaclone/installer");

$ENV{'DEV_INSTALL'} = 1;
$ENV{'KOHA_HOME'} = "/kohadev/kohaclone";

require ("/kohadev/kohaclone/debian/templates/plack.psgi");
