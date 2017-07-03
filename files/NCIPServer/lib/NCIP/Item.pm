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
package NCIP::Item;

use parent qw(Class::Accessor);

=head1 NAME

Item - Defined as ItemInformation in z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 ItemId

Optional NCIP::Item::Id object.

=head2 RequestId

Optional array of NCIP::RequestId objects.

This field occurs only if Problem is not present in the same Item
Information.

=head2 CurrentBorrower

Optional NCIP::User::Id object specifying the user to whom the item is
currently charged.

=head2 DateDue

Optional date/time indicating the due date of the item.

=head2 DateRecalled

Optional date/time indicating the date and time of an item recall.

=head2 HoldPickupDate

Optional date/time indicating when a hold expires for the given item
and user.

=head2 ItemTransaction

Not currently implemented.

=head2 ItemOptionalFields

Optional NCIP::Item::OptionalFields object.

This field occurs only if Problem is not present in the same Item
Information.

=head2 ItemNote

Text string that provides data additional to that provide in other
data elements that comprise Item Information.

Occurs 0 or 1 time but only if Problem is not present in the same Item
Information.

=head2 Problem

Optional NCIP::Problem object to describe some problem with the item request.

Occurs 0 or more times but only if Request Id, Current Borrower,
Current Requester, Date Due, Date Recalled, Hold Pickup Date, Item
Transaction, Item Optional Fields, and Item Note are not present in
the same Item Information element.

=cut

NCIP::Item->mk_accessors(
    qw(
          ItemId
          RequestId
          CurrentBorrower
          DateDue
          DateRecalled
          HoldPickupDate
          ItemTransaction
          ItemOptionalFields
          ItemNote
          Problem
      )
);

1;
