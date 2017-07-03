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
package NCIP::User::PrivilegeStatus;

use parent qw(Class::Accessor);

=head1 NAME

PrivilegeStatus - UserPrivilegeStatus as defined in Z39.83-1-2012.

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 UserPrivilegeStatusType

Text string for the status type, i.e. active, inactive, expired, for
the privilege.

=head2 DateOfUserPrivilegeStatus

Optional date that the privilege entered the given status.

=cut

NCIP::User::PrivilegeStatus->mk_accessors(
    qw(
          UserPrivilegeStatusType
          DateOfUserPrivilegeStatus
      )
);

1;
