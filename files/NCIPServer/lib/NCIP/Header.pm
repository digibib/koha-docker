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
package NCIP::Header;
use parent qw(Class::Accessor);

=head1 NAME

Header - Response Header as Defined in z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

This is a NCIP ResponseHeader object.  We do not implement an
initator, so we do not implement the InitiationHeader and we do not
attempt to make this object generic enough to handle that field.
The fields are as defined in Z39.83-1-2012.  Ext is provided but is
not used by the current iteration of NCIPServer.

=head1 FIELDS

=head2 FromSystemId

Not used in the current implementation.

=head2 FromSystemAuthentication

Not used in the current implementation.

=head2 FromAgencyId

AgencyId of the agency sending the message.

=head2 FromAgencyAuthentication

Not used in the current implementation.

=head2 ToSystemId

Not used in the current implementation.

=head2 ToAgencyId

AgencyId of the agency receiving the message.

=head2 Ext

Not used in the current implementation.


=cut

NCIP::Header->mk_accessors(qw(FromSystemId FromSystemAuthentication
                               FromAgencyId FromAgencyAuthentication
                               ToSystemId ToAgencyId Ext));

1;
