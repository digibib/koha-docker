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
package NCIP::User::BlockOrTrap;

use parent qw(Class::Accessor);

=head1 NAME

BlockOrTrap - as defined in Z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 AgencyId

Text string with the agency identifier for the block or trap.

=head2 BlockOrTrapType

The type of block or trap, i.e. block checkout, block holds....

=head2 ValidFromDate

Optional date that the block starts.

=head2 ValidToDate

Optional date that the block ends.

=cut

NCIP::User::BlockOrTrap->mk_accessors(
    qw(
          AgencyId
          BlockOrTrapType
          ValidFromDate
          ValidToDate
      )
);

1;
