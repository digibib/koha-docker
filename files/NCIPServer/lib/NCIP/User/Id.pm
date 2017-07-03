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
package NCIP::User::Id;

use parent qw(Class::Accessor);

=head1 NAME

Id - UserId obeject as defined in Z39.83-1-2012.

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 AgencyId

Optional text string with the Agency ID.

=head2 UserIdentifierType

Text string with the type of user identifier, i.e. barcode, database id.

=head2 UserIdentifierValue

Text string with the value of the user identifer.

=cut

NCIP::User::Id->mk_accessors(qw(AgencyId UserIdentifierType
                                UserIdentifierValue));

1;
