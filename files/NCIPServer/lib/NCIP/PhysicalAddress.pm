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
package NCIP::PhysicalAddress;
use parent qw(Class::Accessor);


=head1 NAME

PhysicalAddress - A "PhysicalAddress" as defined by Z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

This a "PhysicalAddress" as defined by Z39.83-1-2012.  It is used
for returning user address information when requested.  The fields
are as defined in the standard.

=head1 FIELDS

=head2 StructuredAddress

A NCIP::StructuredAddress object to hold the actual address.

=head2 UnstructuredAddress

Not presently implemented.

=head2 Type

The PhysicalAddressType field. Usually "Postal Address" or "Street Address."

=cut

NCIP::PhysicalAddress->mk_accessors(qw(StructuredAddress Type));

1;
