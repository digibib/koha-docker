# ---------------------------------------------------------------
# Copyright © 2014 Jason J.A. Stephenson <jason@sigio.com>
#
# This file is part of NCIPServer.
#
# NCIPServer is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# NCIPServer is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NCIPServer.  If not, see <http://www.gnu.org/licenses/>.
# ---------------------------------------------------------------
package NCIP::User;

use parent qw(Class::Accessor);

=head1 NAME

User - An object for user information

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 UserId

An array ref of NCIP::User::Id objects.

=head2 UserOptionalFields

A single NCIP::User::OptionalFields object.

=cut


# Make accessors for the ones that makes sense
NCIP::User->mk_accessors(qw(UserId UserOptionalFields));

1;
