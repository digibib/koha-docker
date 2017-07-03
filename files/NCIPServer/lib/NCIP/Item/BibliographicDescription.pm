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
package NCIP::Item::BibliographicDescription;

use parent qw(Class::Accessor);

=head1 NAME

BibliographicDescription - As defined in z39.83-1-2012

=head1 SYNOPSIS



=head1 DESCRIPTION

=head1 FIELDS

=head2 Author

Optional text string for the name of person or corporate body
responsible for the intellectual or artistic content of an Item,
including composers, creators, or originators of an Item.

=head2 AuthorOfComponent

Optional text string for the name of the author of a bibliographic
item that is a component part of another item.

=head2 BibliographicItemId

Optional NCIP::Item::BibliographicItemId object.

=head2 BibliographicRecordId

Optional NCIP::Item::BibliographicRecordId object.

=head2 ComponentId

Optional NCIP::Item::ComponentId object.

=head2 Edition

Optional text string for the edition statement that identifies all the
copies of an item produced from one master copy or substantially the
same type image, having the same contents, and, in the case of
non-book materials, issued by a particular publishing agency or group
of such agencies.

=head2 Pagination

Optional text string that gives number of pages or leaves in an item
or a component part of an item.

=head2 PlaceOfPublication

Optional text string that gives geographic location of the publisher,
or failing this, of the printer, distributor, or manufacturer.

=head2 PublicationDate

Optional text string that gives date of issue of an item as designated
by the publisher.

=head2 PublicationDateOfComponent

Optional text string that gives publication date assigned by the
publisher to the component of an item.

=head2 Publisher

Optional text string to indicate the name of the publisher of an item.

=head2 SeriesTitleNumber

Optional text string representing the name given to a group of
separate publications related to one another by the fact that each
bears a collective title applying to the group or subgroup as a whole
as well as its own title, and the number within that series assigned
to one of the pieces.

=head2 Title

Optional text giving the title of the item.

=head2 TitleOfComponent

Optional text string for the title of an item that is a component part
of another item, such as a chapter of a book, or a journal article,
etc.

=head2 BibliographicLevel

Optional text string for the bibliographic description of the item:
monograph, serial, collection.

=head2 SponsoringBody

Optional text string for the name of the body sponsoring the work.

=head2 ElectronicDataFormatType

Option text string identifying the format of electronic data: tiff,
rtf, jpeg, mpeg, etc.

=head2 Language

Optional text string that identifies the language of the item.

=head2 MediumType

Optional text string for the medium on the item has been produced:
audio tape, book, machine-readable computer file, compact disc, etc.

=cut

NCIP::Item::BibliographicDescription->mk_accessors(
    qw(
          Author
          AuthorOfComponent
          BibliographicItemId
          BibliographicRecordId
          ComponentId
          Edition
          Pagination
          PlaceOfPublication
          PublicationDate
          PublicationDateOfComponent
          Publisher
          SeriesTitleNumber
          Title
          TitleOfComponent
          BibliographicLevel
          SponsoringBody
          ElectronicDataFormatType
          Language
          MediumType
      )
);


1;
