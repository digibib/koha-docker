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
package NCIP::StructuredAddress;
use parent qw(Class::Accessor);


=head1 NAME

StructuredAddress - A "StructuredAddress" as defined by Z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

This a "StructuredAddress" as defined by Z39.83-1-2012.  It is used
for returning user address information when requested.  The fields
are as defined in the standard.

=head1 FIELDS

=head2 Line1

First line of the address.

=head2 Line2

Second line of the address.

=head2 Locality

Locality of the address, typically a city.

=head2 Region

Region of the address, typically a state, province, or department.

=head2 PostalCode

The postal (or zip) code of the address.

=head2 Country

The country of the address.

=cut

NCIP::StructuredAddress->mk_accessors(qw(Line1 Line2 Locality Region PostalCode
                                         Country));

1;
