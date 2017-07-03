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
package NCIP::Problem;
use parent qw(Class::Accessor);

=head1 NAME

Problem - Z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

NCIP::Problem is the object used to report that a problem occurred
during message processing. Ext is avaialable for future use, but it is
not presently used by the problem template.  The obsolete
ProcessingError fields have been excluded.

=head1 FIELDS

=head2 ProblemType

Text string to identify the type of problem that occurred.

=head2 Scheme

URI to indicate the scheme from which the problem type originates. The
data dictionary indicates this field is required. The standard
elsewhere indicates that schemes are optional. Most examples from
vendors omit the scheme.

=head2 ProblemDetail

Text string describing the problem in detail.

=head2 ProblemElement

Text string to indicate the element that caused the problem. It may be
NULL to indicate no element.

=head2 ProblemValue

Text string to indicate the value in which the problem occurred.

=head2 Ext

Not presently used in the templates, but provided as a field defined
by the standard.

=cut

NCIP::Problem->mk_accessors(qw(ProblemType Scheme ProblemDetail ProblemElement
                               ProblemValue Ext));

1;
