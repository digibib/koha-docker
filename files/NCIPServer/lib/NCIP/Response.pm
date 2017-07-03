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
package NCIP::Response;
use parent qw(Class::Accessor);

=head1 NAME

Response - Response object to be returned from ILS' handlers.

=head1 SYNOPSIS



=head1 DESCRIPTION

This is the Response object to be returned by the ILS' handlers.

=head1 FIELDS

Presently, only one data or problem object is supported.  If one is
supplied the other must be left undefined/unset.  Only 1 header is
supported, but it is entirely optional according to the standard.

=head2 type

A string representing the name of the response this is usually the
initiation message name with Response tacked on, i.e.
LookupUserResponse, etc.  This value is used to lookup the appropriate
template for formatting the response message to the initiator.

=head2 data

This is an object or struct with the response data for a successful
result.  It's value and needs vary by message type.

=head2 problem

If the response is reporting a problem, this should point to a
NCIP::Problem object to be used in the problem template.

=head2 header

A NCIP::Header object for the optional ResponseHeader in the response
template.


=cut


NCIP::Response->mk_accessors(qw(type data problem header));

1;
