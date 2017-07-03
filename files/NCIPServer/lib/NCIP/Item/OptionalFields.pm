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
package NCIP::Item::OptionalFields;

use parent qw(Class::Accessor);

=head1 NAME

OptionalFields - As defined in z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 BibliographicDescription

Optional NCIP::Item::BibliographicDescription object.

=head2 ItemUseRestrictionType

Optional text string to indicate special usage rules or restrictions
on the item.

=head2 CirculationStatus

Optional text string to indicate the current availability of a
bibliographic item: available, on loan, lost, etc.

=head2 HoldQueueLength

Optional, non-negative integer for the number of user who currently
have a hold on the item.

=head2 DateDue

Optional date value that specifies the time when the loan of an item
will end.

=head2 ItemDescription

Optional NCIP::Item::Description object.

=head2 Location

Not currently implemented.

=head2 PhysicalCondition

Optional NCIP::Item::PhysicalCondition object.

=head2 ElectronicResource

Not currently implemented.

=head2 SecurityMarker

Optional text sting to specify the type of security used on an item.

=head2 SensitizationFlag

Set to 1 when the item should be desensitized or re-sensitized during
check out and check in.

=head2 Ext

=cut

NCIP::Item::OptionalFields->mk_accessors(
    qw(
          BibliographicDescription
          ItemUseRestrictionType
          CirculationStatus
          HoldQueueLength
          DateDue
          ItemDescription
          Location
          PhysicalCondition
          ElectronicResource
          SecurityMarker
          SensitizationFlag
          Ext
      )
);

1;
