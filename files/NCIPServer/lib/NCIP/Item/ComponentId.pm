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
package NCIP::Item::ComponentId;

use parent qw(Class::Accessor);

=head1 NAME

ComponentId - As defined in z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 ComponentIdentifierType

Text string that identifies a component part of a bibliographic item.

=head2 ComponentIdentifier

Text string that identifies component part of another bibliographic
item.

=cut

NCIP::Item::ComponentId->mk_accessors(
    qw(
          ComponentIdentifierType
          ComponentIdentifier
      )
);

1;
