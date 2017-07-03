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
package NCIP::Item::BibliographicRecordId;

use parent qw(Class::Accessor);

=head1 NAME

BibliographicRecordId - As defined in z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

Bibliographic Record Id consists of Bibliographic Record Identifier
and a choice of either Bibliographic Record Identifier Code OR Agency
Id.

Occurs 0 or more times.

None of these component elements are repeatable.

=head1 FIELDS

=head2 BibliographicRecordIdentifier

Text string that identifies the machine-readable record that describes
a bibliographic item.

Occurs 1 and only 1 time.

=head2 AgencyId

In this context, identifies the Agency that is the source of the
bibliographic record when that Agency is not listed explicitly as a
value in the Bibliographic Record Identifier Code.

Occurs 1 and only 1 time, but only if Bibliographic Record Identifier
Code is not present.

=head2 BibliographicRecordIdentifierCode

Text string to identify the numbering scheme that uniquely identifies
a bibliographic record. Code values are usually associated with
national bibliographies or bibliographic utilities.

Occurs 1 and only 1 time, but only if Agency Id is not present.

Examples: ANBN (Australian National Bibliography Number), BNBN
(British National Bibliography Number), LCCN (Library of Congress
Control Number)

=cut

NCIP::Item::BibliographicRecordId->mk_accessors(
    qw(
          BibliographicRecordIdentifier
          AgencyId
          BibliographicRecordIdentifierCode
      )
);

1;
