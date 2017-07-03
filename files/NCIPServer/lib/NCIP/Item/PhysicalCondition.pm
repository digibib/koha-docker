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
package NCIP::Item::PhysicalCondition;

use parent qw(Class::Accessor);

=head1 NAME

PhysicalCondition - As defined in z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 PhysicalConditionType

Required text string that describes the physical condition of the
item.

=head2 PhysicalConditionDetails

Optional text string to provide more details about the physical
condition of the item.

=cut

NCIP::Item::PhysicalCondition->mk_accessors(
    qw(
          PhysicalConditionType
          PhysicalConditionDetails
      )
);

1;
