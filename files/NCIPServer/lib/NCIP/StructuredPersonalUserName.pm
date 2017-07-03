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
package NCIP::StructuredPersonalUserName;

use parent qw(Class::Accessor);

# The name of this class is a bit unwieldy, but comes directly from
# the standard.  I wonder if we shouldn't rename for our own sanity.

=head1 NAME

StructuredPersonalUserName - Object to hold name information

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

The fields are text strings.

=head2 Prefix

Optional field to hold the user's name prefix.

=head2 GivenName

Optional field to hold the user's given, or first, name.

=head2 Surname

Required field to hold the user's surname. This is the user's family
name.

This field is required by the standard and also so the code may tell
the difference from an unstructured name if we ever support it.

=head2 Initials

Optional field for the user's name initials.

=head2 Suffix

Optional field for the user's name suffix, if any.

=cut

NCIP::StructuredPersonalUserName->mk_accessors(
    qw(Prefix GivenName Surname Initials Suffix)
);

1;
