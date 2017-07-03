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
package NCIP::User::OptionalFields;

use parent qw(Class::Accessor);

=head1 NAME

OptionalFields - Data class for the UserOptionalFields

=head1 SYNOPSIS



=head1 DESCRIPTION

This data class holds the information for the UserOptionalFields. Most
of the fields of this class all hold array refs of data objects as
defined below. The one exception is NameInformation which only appears
once.

All of the fields are optional.

=head1 FIELDS

=head2 NameInformation

This field holds the name information for the user. Currently, the
templates ony support StructuredPersonalUserName.

=head2 UserAddressInformation

This is an array reference that contains
NCIP::User::AddressInformation objects for the user's addresses. We
currently only support StructuredAddress for physical addresses.

=head2 UserLanguage

A array of text strings indicating the user's languages.

=head2 BlockOrTrap

An array of NCIP::User::BlockOrTrap.

=head2 UserPrivilege

An array of NCIP::User::Privilege.

=head2 PreviousUserId

Not presently implemented.

=cut

NCIP::User::OptionalFields->mk_accessors(
    qw(
          NameInformation
          UserAddressInformation
          UserLanguage
          BlockOrTrap
          UserPrivilege
          PreviousUserId
      )
);

1;
