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
package NCIP::Item::Description;

use parent qw(Class::Accessor);

=head1 NAME

Description - As described in z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 CallNumber

Optional text string for the call number of the item.

=head2 CopyNumber

Optional text string to identify the copy number of the item.

=head2 ItemDescriptionLevel

Optional text string to indicate the level at which the item is
described, for example: work, copy or piece.

=head2 HoldingsInformation

This optional field is not supported by NCIPServer at this time. If
you fill in any information for it, that information will be ignored.

=head2 NumberOfPieces

Optional integer to specify the number of pieces that comprise this
item.

=cut

NCIP::Item::Description->mk_accessors(
    qw(
          CallNumber
          CopyNumber
          ItemDescriptionLevel
          HoldingsInformation
          NumberOfPieces
          Ext
      )
);

1;
