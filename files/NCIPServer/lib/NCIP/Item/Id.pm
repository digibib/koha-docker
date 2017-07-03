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
package NCIP::Item::Id;

use parent qw(Class::Accessor);

=head1 NAME

Id - As defined in Z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION


=head1 FIELDS

=head2 AgencyId

Optional text string to identify the agency that assigned the
identifier to the item.

=head2 ItemIdentifierType

Optional text string to indicate the type of identifier value, i.e. a
barcode or database ID.

=head2 ItemIdentifierValue

Required text string to represent the value of the item identifier.

=cut

NCIP::Item::Id->mk_accessors(
    qw(
          AgencyId
          ItemIdentifierType
          ItemIdentiferValue
      )
);

1;
