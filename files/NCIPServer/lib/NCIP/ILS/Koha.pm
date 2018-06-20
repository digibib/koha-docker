#
#===============================================================================
#
#         FILE: Koha.pm
#
#  DESCRIPTION:
#
#        FILES: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: Chris Cormack (rangi), chrisc@catalyst.net.nz, Magnus Enger (magnuse) magnus@libriotech.no
# ORGANIZATION: Koha Development Team
#      VERSION: 1.0
#      CREATED: 05/11/13 11:14:09
#     REVISION: ---
#===============================================================================
package NCIP::ILS::Koha;

use Modern::Perl;
use Data::Dumper; # FIXME Debug
use Date::Parse qw( str2time );
use Dancer ':syntax';
use Try::Tiny;

use C4::Biblio;
use C4::Circulation qw { AddRenewal CanBookBeRenewed GetRenewCount };
use C4::Items qw { AddItem GetItem GetItemsByBiblioitemnumber };
use C4::Reserves qw { CanBookBeReserved CanItemBeReserved AddReserve };
use C4::Log;

use Koha::DateUtils qw { dt_from_string };
use Koha::Illrequests;
use Koha::Illrequest::Config;
use Koha::Libraries;
use Koha::Biblio;
use Koha::Biblios;
use Koha::Patrons;
use Koha::Hold;

use NCIP::Item::Id;
use NCIP::Problem;
use NCIP::RequestId;
use NCIP::User::Id;
use NCIP::Item::BibliographicDescription;

# Inherit from NCIP::ILS.
use parent qw(NCIP::ILS);

=head1 NAME

Koha - Koha driver for NCIPServer

=head1 SYNOPSIS

    my $ils = NCIP::ILS::Koha->new(name => $config->{NCIP.ils.value});

=cut

# The usual constructor:
sub new {
    my $class = shift;
    $class = ref($class) if (ref $class);

    # Instantiate our parent with the rest of the arguments.  It
    # creates a blessed hashref.
    my $self = $class->SUPER::new(@_);

    # Look for our configuration file, load, and parse it:
    # $self->_configure();

    # Bootstrap OpenSRF and prepare some OpenILS components.
    # $self->_bootstrap();

    # Initialize the rest of our internal state.
    # $self->_init();

    return $self;
}

=head1 HANDLER METHODS

=head2 lookupagency

    $response = $ils->lookupagency($request);

Handle the NCIP LookupAgency message.

=cut

sub lookupagency {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    my $library = Koha::Libraries->find({ 'branchcode' => config->{'isilmap'}->{ $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId} } });

    my $data = {
        fromagencyid => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        toagencyid => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        RequestType => $request->{$message}->{RequestType},
        library => $library,
        orgtype => ucfirst C4::Context->preference( "UsageStatsLibraryType" ),
        applicationprofilesupportedtype => 'NNCIPP 1.0',
    };

    $response->data($data);
    return $response;

}

=head2 itemshipped

    $response = $ils->itemshipped($request);

Handle the NCIP ItemShipped message.

This gets called in two different ways:

1. The Owner Library has shipped an item to the Home Library. Status changes
from H_REQUESTITEM to H_ITEMSHIPPED. This is NNCIPP call number 4. This should
also trigger a hold at the Home Library, to connect the item with the actual
patron waiting for it.

2. The Home Library has shipped an item back to the Owner Library. Status
changes from O_ITEMRECEIVED to O_RETURNED. This is NNCIPP call number 6.

=cut

# Ideally we should trust RequestId in message, but RequestId->AgencyId might be missing or wrong...
sub _getRequestByOrderId {
    my $msg = shift;
    my $req;
    $req = Koha::Illrequests->find({ orderid => $msg->{RequestId}->{AgencyId} . ":" . $msg->{RequestId}->{RequestIdentifierValue} });
    $req = Koha::Illrequests->find({ orderid => $msg->{InitiationHeader}->{FromAgencyId}->{AgencyId} . ":" . $msg->{RequestId}->{RequestIdentifierValue} }) unless $req;
    $req = Koha::Illrequests->find({ orderid => $msg->{InitiationHeader}->{ToAgencyId}->{AgencyId} . ":" . $msg->{RequestId}->{RequestIdentifierValue} }) unless $req;
    return $req;
}

sub itemshipped {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Change the status of the request
    # Find the request
    my $saved_request = _getRequestByOrderId($request->{$message});

    unless ( $saved_request ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unknown Request ID',
            ProblemDetail  => "Request ID with value " . $request->{$message}->{RequestId}->{RequestIdentifierValue} . "not found",
            ProblemElement => 'RequestId',
            ProblemValue   => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        });
        $response->problem( $problem );
        return $response;
    }

    # Check if we are the Home Library or not
    if ( $saved_request->status eq 'H_REQUESTITEM' ) {
        # We are the Home Library and we are being told that the Owner Library
        # has shipped the item we want (or a replacement for it)
        # Find the item
        my $biblio_id = $saved_request->biblio_id or die "no biblio_id on saved_request";
        my $biblio = Koha::Biblios->find({ 'biblionumber' => $biblio_id });
        my @items = $biblio->items();
        @items == 1 or die "expected only 1 entry for $biblio_id, got: ".scalar(@items);
        my $item = $items[0];
        my @identifier_types = split(";", $request->{$message}->{ItemId}->{ItemIdentifierType});
        my @identifiers = split(";", $request->{$message}->{ItemId}->{ItemIdentifierValue});
        for (my $i=0; $i<@identifier_types; $i++) {
            my $id_type = @identifier_types[$i];
            my $id = @identifiers[$i];
            if ($id_type eq "Barcode") {
                $saved_request->illrequestattributes->find({ type => 'ItemIdentifierType' })->value('Barcode')->store();
                $saved_request->illrequestattributes->find({ type => 'ItemIdentifierValue' })->value($id)->store();
                $item->itemnotes("ILL barcode: " . $id);
            }
            if ($id_type eq "RFID") {
                $saved_request->illrequestattributes->find_or_create({ type => 'RFID' })->value($id)->store();
            }
        }

        $item->store;
        warn "Setting status to H_ITEMSHIPPED";
        $saved_request->status( 'H_ITEMSHIPPED' )->store;
    } elsif ( $saved_request->status eq 'O_ITEMRECEIVED' ) {
        $saved_request->status( 'O_RETURNED' )->store;
    }

    my $data = {
        fromagencyid           => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        toagencyid             => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        AgencyId               => $request->{$message}->{RequestId}->{AgencyId},
        RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        RequestType            => $request->{$message}->{RequestType},
    };

    $response->data($data);
    return $response;

}

=head2 itemreceived

    $response = $ils->itemreceived($request);

Handle the NCIP ItemReceived message.

Set status = RECEIVED.

=cut

sub itemreceived {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Change the status of the request
    # Find the request
    my $saved_request = _getRequestByOrderId($request->{$message});

    # Check if we are the Owner Library or not
    if ( $saved_request->status eq 'O_ITEMSHIPPED' ) {
        # We are the Owner Library, so this is #5
        $saved_request->status( 'O_ITEMRECEIVED' )->store;
    } elsif ( $saved_request->status eq 'H_RETURNED' ) {
        # We are the Home Library, so this is #7
        $saved_request->status( 'DONE' )->store;
        # The transaction is now complete, so we can safely delete
        # the temproary biblio and associated item.
        if (my $biblio_id = $saved_request->biblio_id) {
            my $biblio = Koha::Biblios->find({ 'biblionumber' => $biblio_id });
            my $items = $biblio->items;
            while (my $item = $items->next ) {
                C4::Items::DelItem({itemnumber => $item->itemnumber, biblionumber => $biblio_id});
            }
            C4::Biblio::DelBiblio($biblio_id);
        }
    }

    my $data = {
        fromagencyid           => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        toagencyid             => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        AgencyId               => $request->{$message}->{RequestId}->{AgencyId},
        RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        RequestType            => $request->{$message}->{RequestType},
    };

    $response->data($data);
    return $response;

}

=head2 requestitem

    $response = $ils->requestitem($request);

Handle the NCIP RequestItem message.

=cut

sub requestitem {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Find the library (patron) based on the FromAgencyId
    my $cardnumber = _isil2barcode( $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId} );
    my $patron = Koha::Patrons->find({cardnumber => $cardnumber});

    unless ( $patron ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unknown User',
            ProblemDetail  => "User with barcode $cardnumber unknown",
            ProblemElement => 'AgencyId',
            ProblemValue   => 'NULL',
        });
        $response->problem( $problem );
        return $response;
    }

    my $biblionumber;
    # Find the identifier and the identifiertype from the request, if there is one
    # We have either
    #    ItemIdentifierType + ItemIdentifierValue
    # or
    #    BibliographicRecordIdentifierCode + BibliographicRecordIdentifier
    my $itemidentifiertype;
    my $itemidentifiervalue;
    if ( $request->{$message}->{ItemId}->{ItemIdentifierType} && $request->{$message}->{ItemId}->{ItemIdentifierValue} ) {
        $itemidentifiertype  = $request->{$message}->{ItemId}->{ItemIdentifierType};
        $itemidentifiervalue = $request->{$message}->{ItemId}->{ItemIdentifierValue};
    } else {
        $itemidentifiertype  = $request->{$message}->{BibliographicId}->{BibliographicRecordId}->{BibliographicRecordIdentifierCode};
        $itemidentifiervalue = $request->{$message}->{BibliographicId}->{BibliographicRecordId}->{BibliographicRecordIdentifier};
    }
    # my ( $barcode, $barcode_field ) = $self->find_item_barcode($request);
    if ( $itemidentifiervalue eq '') {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Missing Item identifier',
            ProblemDetail  => "No ItemIdentifierValue given",
            ProblemElement => 'NULL',
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    } elsif ( $itemidentifiertype eq "Barcode" ) {
        # We have a barcode (or something passing itself off as a barcode),
        # try to use it to get item data
        my $itemdata = GetItem( undef, $itemidentifiervalue );
        unless ( $itemdata ) {
            my $problem = NCIP::Problem->new({
                ProblemType    => 'Unknown Item',
                ProblemDetail  => "Item $itemidentifiervalue is unknown",
                ProblemElement => 'ItemIdentifierValue',
                ProblemValue   => $itemidentifiervalue,
            });
            $response->problem($problem);
            return $response;
        }
        $biblionumber = $itemdata->{'biblionumber'};
    } elsif ( $itemidentifiertype eq "ISBN" || $itemidentifiertype eq "ISSN" || $itemidentifiertype eq "EAN" ) {
        $biblionumber = _get_biblionumber_from_standardnumber( lc( $itemidentifiertype ), $itemidentifiervalue );
        unless ( $biblionumber ) {
            my $problem = NCIP::Problem->new({
                ProblemType    => 'Unknown Item',
                ProblemDetail  => "Item $itemidentifiervalue is unknown",
                ProblemElement => 'ItemIdentifierValue',
                ProblemValue   => $itemidentifiervalue,
            });
            $response->problem($problem);
            return $response;
        }
    } elsif ( $itemidentifiertype eq "OwnerLocalRecordID" ) {
        $biblionumber = $itemidentifiervalue;
    } else {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unsupported type',
            ProblemDetail  => "Item Identifier Type $itemidentifiertype is not supported",
            ProblemElement => 'NULL',
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    my $bibliodata  = GetBiblioData( $biblionumber );

    # Bail out if we have no data by now
    unless ( $bibliodata ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unknown Item',
            ProblemDetail  => "Item is unknown",
            ProblemElement => 'NULL',
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    # We might get requestitem directly, so need to check if remote reserve is allowed for this item
    my $approved = _isApprovedForRemoteReserve($biblionumber);
    unless ($approved) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Not approved',
            ProblemDetail  => "Material not approved for remote reserval",
            ProblemElement => 'NULL',
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    # Check if the order is already stored:
    my $saved_request = _getRequestByOrderId($request->{$message});
    my $comment;

    unless ($saved_request) {
        # Save the request
        my $illrequest = Koha::Illrequest->new;
        $illrequest->load_backend( 'NNCIPP' );
        if ($request->{$message}->{Ext} and $request->{$message}->{Ext}->{ItemNote}) {
            $comment = $request->{$message}->{Ext}->{ItemNote};
        }
        $illrequest->backend_create({
            'borrowernumber' => $patron->borrowernumber,
            'biblionumber'   => $biblionumber,
            'branchcode'     => 'ILL', # FIXME
            'status'         => 'O_REQUESTITEM',
            'backend'        => 'NNCIPP',
            'attr'           => {
                'requested_by' => _isil2barcode( $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId} ),
                'UserIdentifierValue'    => $request->{$message}->{UserId}->{UserIdentifierValue},
                'ItemIdentifierType'     => $itemidentifiertype,
                'ItemIdentifierValue'    => $itemidentifiervalue,
                'AgencyId'               => $request->{$message}->{RequestId}->{AgencyId},
                'RequestIdentifierValue' => $request->{$message}->{RequestId}->{RequestIdentifierValue},
                'RequestType'            => $request->{$message}->{RequestType},
                'RequestScopeType'       => $request->{$message}->{RequestScopeType},
                'KohaReserveId'          => undef,
                'Comment'                => $comment,
            },
            'stage'          => 'commit',
        });

        # Check if the book (record level) can be reserved
        # TODO: Should we add more logic here?
        my $canReserve = CanBookBeReserved( $patron->borrowernumber, $biblionumber );
        if ($canReserve eq 'OK') {
            try {
                my $hold = Koha::Hold->new(
                    {
                        branchcode     => 'ILL',                            # branch FIXME Should this be not hardcoded? Should it be the branch the book belongs to?
                        borrowernumber => $patron->borrowernumber,
                        biblionumber   => $biblionumber,
                        reservedate    => dt_from_string()->ymd,
                        lowestPriority => 1,                                # Ill Requests always keep lowest priority
                        reservenotes   => 'Hold placed by NNCIPP',
                    }
                );
                $hold->store();
                C4::Reserves::_FixPriority({ biblionumber => $hold->biblionumber });
                $illrequest->illrequestattributes->find({ type => 'KohaReserveId' })->value($hold->id())->store();
            } catch {
                my $errmsg;
                if ( $_->isa('DBIx::Class::Exception') ) {
                    $errmsg = "ERROR PLACING HOLD: $_->{msg}";
                } else {
                    $errmsg = "Cannot place hold, pleace check the logs.";
                }

                my $problem = NCIP::Problem->new({
                    ProblemType    => 'ERROR PLACING HOLD',
                    ProblemDetail  => $errmsg,
                    ProblemElement => 'NULL',
                    ProblemValue   => 'NULL',
                });
                $response->problem($problem);
                return $response;
            }
        } else {
            my $problem = NCIP::Problem->new({
                ProblemType    => 'CANNOT PLACE HOLD',
                ProblemDetail  => 'NULL',
                ProblemElement => 'NULL',
                ProblemValue   => $canReserve,
            });
            $response->problem($problem);
            return $response;
        }
    }

    # Build the response
    my $data = {
        ToAgencyId   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        FromAgencyId => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        RequestId => NCIP::RequestId->new({
            # Echo back the RequestIdentifier found in the request
            AgencyId => $request->{$message}->{RequestId}->{AgencyId},
            RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        }),
        UserId => NCIP::User::Id->new(
            {
                UserIdentifierValue => $request->{$message}->{UserId}->{UserIdentifierValue},
            }
        ),
        RequestType => $request->{$message}->{RequestType},
        ItemOptionalFields => NCIP::Item::BibliographicDescription->new(
            {
                Author             => $bibliodata->{'author'} || 'Unknown',
                PlaceOfPublication => $bibliodata->{'place'},
                PublicationDate    => $bibliodata->{'copyrightdate'},
                Publisher          => $bibliodata->{'publishercode'},
                Title              => $bibliodata->{'title'},
                BibliographicLevel => 'Book', # FIXME
                Language           => _get_langcode_from_bibliodata( $bibliodata ),
                MediumType         => undef, # FIXME: not used for now
            }
        ),
        Ext => {
            ItemNote => $comment,
        }
    };

    # Add proper Item Identifier in response
    if (keys %{$request->{$message}->{ItemId}}) {
        $data->{ItemId} = NCIP::Item::Id->new(
            {
                ItemIdentifierType => $itemidentifiertype,
                ItemIdentifierValue => $itemidentifiervalue,
            }
        );
    } elsif (keys %{$request->{$message}->{BibliographicId}}) {
        $data->{BibliographicId} = NCIP::Item::BibliographicRecordId->new(
            {
                BibliographicRecordIdentifierCode => $itemidentifiertype,
                BibliographicRecordIdentifier => $itemidentifiervalue,
            }
        );
    }

    $response->data($data);
    return $response;

}

=head2 itemrequested

    $response = $ils->itemrequested($request);

Handle the NCIP ItemRequested message.
We are ordering agency and receive info needed to place the request on the owning library.
  - saves Illrequest with status H_ITEMREQUESTED
  - creates tmp biblio and item with branchcode 'ILL'

=cut

sub itemrequested {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    my $ok = 1;
    my ($error_type, $error_detail);

    # Get the ID of library we ordered from
    my $ordered_from = _isil2barcode( $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId} );
    my $ordered_from_patron = Koha::Patrons->find({ cardnumber => $ordered_from });
    unless ($ordered_from && $ordered_from_patron) {
        $ok = 0;
        $error_type   = "Missing Agency Info";
        $error_detail = "Missing valid Agency ID" unless $ordered_from;
        $error_detail = "Cannot find Agency Patron in DB: $ordered_from" unless $ordered_from_patron;
    }

    my $ordering_agency = _isil2barcode( $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId} );
    my $ordering_agency_patron = Koha::Patrons->find({ cardnumber => $ordering_agency });
    unless ($ordering_agency && $ordering_agency_patron) {
        $ok = 0;
        $error_type   = "Missing Ordering Agency Info";
        $error_detail = "Missing valid Ordering Agency ID" unless $ordering_agency;
        $error_detail = "Cannot find Ordering Agency Patron in DB: $ordering_agency_patron" unless $ordering_agency_patron;
    }

    my $itemidentifiertype = $request->{$message}->{ItemId}->{ItemIdentifierType} //
        $request->{$message}->{BibliographicId}->{BibliographicRecordId}->{BibliographicRecordIdentifierCode};
    my $itemidentifiervalue = $request->{$message}->{ItemId}->{ItemIdentifierValue} //
        $request->{$message}->{BibliographicId}->{BibliographicRecordId}->{BibliographicRecordIdentifier};

    unless ($itemidentifiertype && $itemidentifiervalue) {
        $ok = 0;
        $error_type   = "Missing Identifier";
        $error_detail = "No valid Item Identifier Type found" unless $itemidentifiertype;
        $error_detail = "No valid Item Identifier Value found" unless $itemidentifiervalue;
    }

    unless ( $ok ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => $error_type,
            ProblemDetail  => $error_detail,
            ProblemElement => $itemidentifiertype,
            ProblemValue   => $itemidentifiervalue,
        });
        $response->problem($problem);
        return $response;
    }

    # If the request is coming from our own library, we don't want to create a new biblio and item, but
    # simply place a hold on our allready existing biblio
    if ($ordered_from eq C4::Context->preference('ILLISIL')) {
        return $self->_localitemrequested($request, $response);
    }

    # Create a minimal MARC record based on ItemOptionalFields
    # FIXME This could be done in a more elegant way
    my $bibdata = $request->{$message}->{ItemOptionalFields}->{BibliographicDescription};

    my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
    $doc->setStandalone(1);
    my $root = $doc->createElement('record');
    $doc->setDocumentElement($root);
    {
        my $datafield = $doc->createElement('datafield');
        $datafield->setAttribute(tag => '100');
        $datafield->setAttribute(ind1 => ' ');
        $datafield->setAttribute(ind2 => ' ');
        my $subfield = $doc->createElement('subfield');
        $subfield->setAttribute(code => 'a');
        $subfield->appendText($bibdata->{Author} // '');
        $root->appendChild($datafield);
        $datafield->appendChild($subfield);
    }
    {
        my $datafield = $doc->createElement('datafield');
        $datafield->setAttribute(tag => '245');
        $datafield->setAttribute(ind1 => ' ');
        $datafield->setAttribute(ind2 => ' ');
        my $subfield = $doc->createElement('subfield');
        $subfield->setAttribute(code => 'a');
        $subfield->appendText($bibdata->{Title} // '');
        $root->appendChild($datafield);
        $datafield->appendChild($subfield);
    }

    if ( $bibdata->{PlaceOfPublication} || $bibdata->{Publisher} || $bibdata->{PublicationDate} ) {
        my $datafield = $doc->createElement('datafield');
        $datafield->setAttribute(tag => '260');
        $datafield->setAttribute(ind1 => ' ');
        $datafield->setAttribute(ind2 => ' ');
        if ( $bibdata->{PlaceOfPublication} ) {
            my $subfield = $doc->createElement('subfield');
            $subfield->setAttribute(code => 'a');
            $subfield->appendText($bibdata->{PlaceOfPublication});
            $datafield->appendChild($subfield);
        }
        if ( $bibdata->{Publisher} ) {
            my $subfield = $doc->createElement('subfield');
            $subfield->setAttribute(code => 'b');
            $subfield->appendText($bibdata->{Publisher});
            $datafield->appendChild($subfield);
        }
        if ( $bibdata->{PublicationDate} ) {
            my $subfield = $doc->createElement('subfield');
            $subfield->setAttribute(code => 'c');
            $subfield->appendText($bibdata->{PublicationDate});
            $datafield->appendChild($subfield);
        }
        $root->appendChild($datafield);
    }

    my $record = MARC::Record->new_from_xml( $doc->toString(), 'UTF-8' );
    my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $record, 'FA' );
    warn "biblionumber $biblionumber created";

    # Add an item
    # FIXME Data should not be hardcoded
    my ( $x_biblionumber, $x_biblioitemnumber, $itemnumber ) = AddItem({
            'homebranch'    => 'ILL',
            'holdingbranch' => 'ILL',
            'itype'         => 'ILL',
        }, $biblionumber );
    warn "itemnumber $itemnumber created";

    my $item = Koha::Items->find($itemnumber);
    $item->barcode(undef);
    $item->store();

    # Get the patron that the request is meant for
    my $cardnumber = $request->{$message}->{UserId}->{UserIdentifierValue};
    my $patron = Koha::Patrons->find({ cardnumber => $cardnumber });

    # Save a new request with the newly created biblionumber
    my $illrequest = Koha::Illrequest->new;
    $illrequest->load_backend( 'NNCIPP' );
    my $comment;
    if ( $request->{$message}->{Ext} and $request->{$message}->{Ext}->{ItemNote} ) {
        $comment = $request->{$message}->{Ext}->{ItemNote};
    }

    # Place a hold
    my $canReserve = CanItemBeReserved( $patron->borrowernumber, $item->itemnumber );
    my $hold;
    if ($canReserve eq 'OK') {
        try {
            $hold = Koha::Hold->new(
                    {
                    branchcode     => $patron->branchcode,       # Place hold on branchcode of ordering agency
                    borrowernumber => $patron->borrowernumber,
                    biblionumber   => $item->biblionumber,
                    reservedate    => dt_from_string()->ymd,
                    lowestPriority => 1,                                # Ill Requests always keep lowest priority
                    reservenotes   => 'Hold placed by NNCIPP',
                    itemnumber     => $item->itemnumber,       # Itemnumber when specific barcode is selected
                    }
                    )->store();
            C4::Reserves::_FixPriority({ biblionumber => $item->biblionumber });
        } catch {
            if ( $_->isa('DBIx::Class::Exception') ) {
                die "ERROR PLACING HOLD: $_->{msg}";
            } else {
                die "Can not place hold, pleace check the logs.";
            }
        }
    } else {
        warn "Can not place hold: $canReserve";
    }

    my $backend_result = $illrequest->backend_create({
        borrowernumber => $patron->borrowernumber,
        biblionumber   => $biblionumber,
        branchcode     => $ordering_agency_patron->branchcode, # Save branchcode for ordering agency
        status         => 'H_ITEMREQUESTED',
        medium         => $bibdata->{MediumType},
        backend        => 'NNCIPP',
        attr           => {
            title        => $bibdata->{Title},
            author       => $bibdata->{Author},
            ownerLabel   => $ordered_from_patron->surname,
            ordered_from => $ordered_from,
            ordered_from_borrowernumber => $ordered_from_patron->borrowernumber,
            PlaceOfPublication  => $bibdata->{PlaceOfPublication},
            Publisher           => $bibdata->{Publisher},
            PublicationDate     => $bibdata->{PublicationDate},
            Language            => $bibdata->{Language},
            ItemIdentifierType  => $itemidentifiertype,
            ItemIdentifierValue => $itemidentifiervalue,
            RequestType         => $request->{$message}->{RequestType},
            RequestScopeType    => $request->{$message}->{RequestScopeType},
            'KohaReserveId'     => $hold->id(),
            Comment             => $comment,
        },
        stage          => 'commit',
    });

    # Data for ItemRequestedResponse
    my $data = {
        RequestType  => $message,
        ToAgencyId   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        FromAgencyId => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        UserId       => $request->{$message}->{UserId}->{UserIdentifierValue},
        ItemOptionalFields => NCIP::Item::BibliographicDescription->new(
            {
                Author             => $bibdata->{Author},
                PlaceOfPublication => $bibdata->{PlaceOfPublication},
                PublicationDate    => $bibdata->{PublicationDate},
                Publisher          => $bibdata->{Publisher},
                Title              => $bibdata->{Title},
                Language           => $bibdata->{Language},
                MediumType         => $bibdata->{MediumType},
            }
        ),
    };

    # Add proper Item Identifier in response
    if (keys %{$request->{$message}->{ItemId}}) {
        $data->{ItemId} = NCIP::Item::Id->new(
            {
                ItemIdentifierType => $itemidentifiertype,
                ItemIdentifierValue => $itemidentifiervalue,
            }
        );
    } elsif (keys %{$request->{$message}->{BibliographicId}}) {
        $data->{BibliographicId} = NCIP::Item::BibliographicRecordId->new(
            {
                BibliographicRecordIdentifierCode => $itemidentifiertype,
                BibliographicRecordIdentifier => $itemidentifiervalue,
            }
        );
    }
    $response->data($data);
    return $response;

    # This should trigger an immediate RequestItem back to the Owner Library
    # But the server should probably not be the one sending it...

}


sub _localitemrequested {
    my $self = shift;
    my $request = shift;
    my $response = shift;
    my $message = $self->parse_request_type($request);

    my $itemidentifiertype = $request->{$message}->{ItemId}->{ItemIdentifierType} //
        $request->{$message}->{BibliographicId}->{BibliographicRecordId}->{BibliographicRecordIdentifierCode};
    my $itemidentifiervalue = $request->{$message}->{ItemId}->{ItemIdentifierValue} //
        $request->{$message}->{BibliographicId}->{BibliographicRecordId}->{BibliographicRecordIdentifier};

    my $bibdata = $request->{$message}->{ItemOptionalFields}->{BibliographicDescription};

    # Get the patron that the request is meant for
    my $cardnumber = $request->{$message}->{UserId}->{UserIdentifierValue};
    my $patron = Koha::Patrons->find({ cardnumber => $cardnumber });

    # Place a hold
    my $canReserve = CanBookBeReserved( $patron->borrowernumber, $itemidentifiervalue );
    my $hold;
    if ($canReserve eq 'OK') {
        try {
            $hold = Koha::Hold->new(
                    {
                    branchcode     => $patron->branchcode,
                    borrowernumber => $patron->borrowernumber,
                    biblionumber   => $itemidentifiervalue,
                    reservedate    => dt_from_string()->ymd,
                    reservenotes   => 'Hold placed by NNCIPP',
                    }
                    )->store();
            C4::Reserves::_FixPriority({ biblionumber => $itemidentifiervalue });
        } catch {
            if ( $_->isa('DBIx::Class::Exception') ) {
                die "ERROR PLACING HOLD: $_->{msg}";
            } else {
                die "Can not place hold, pleace check the logs.";
            }
        }
    } else {
        warn "Can not place hold: $canReserve";
    }

    # Data for ItemRequestedResponse
    my $data = {
        RequestType  => $message,
        ToAgencyId   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        FromAgencyId => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        UserId       => $request->{$message}->{UserId}->{UserIdentifierValue},
        ItemOptionalFields => NCIP::Item::BibliographicDescription->new(
            {
                Author             => $bibdata->{Author},
                PlaceOfPublication => $bibdata->{PlaceOfPublication},
                PublicationDate    => $bibdata->{PublicationDate},
                Publisher          => $bibdata->{Publisher},
                Title              => $bibdata->{Title},
                Language           => $bibdata->{Language},
                MediumType         => $bibdata->{MediumType},
            }
        ),
    };


    $data->{BibliographicId} = NCIP::Item::BibliographicRecordId->new(
        {
            BibliographicRecordIdentifierCode => $itemidentifiertype,
            BibliographicRecordIdentifier => $itemidentifiervalue,
        }
    );

    $response->data($data);
    return $response;
}

=head2 renewitem

    $response = $ils->renewitem($request);

Handle the NCIP RenewItem message.

=cut

sub renewitem {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Find the cardnumber of the patron
    # my ( $cardnumber, $cardnumber_field ) = $self->find_user_barcode( $request );
    # unless( $cardnumber ) {
    #     my $problem = NCIP::Problem->new({
    #         ProblemType    => 'Needed Data Missing',
    #         ProblemDetail  => 'Cannot find user barcode in message',
    #         ProblemElement => $cardnumber_field,
    #         ProblemValue   => 'NULL',
    #     });
    #     $response->problem($problem);
    #     return $response;
    # }

    # Find the borrower based on the cardnumber
    # my $borrower = GetMember( 'cardnumber' => $cardnumber );
    # unless ( $borrower ) {
    #     my $problem = NCIP::Problem->new({
    #         ProblemType    => 'Unknown User',
    #         ProblemDetail  => "User with barcode $cardnumber unknown",
    #         ProblemElement => $cardnumber_field,
    #         ProblemValue   => 'NULL',
    #     });
    #     $response->problem($problem);
    #     return $response;
    # }

    my $itemdata;
    # Find the barcode from the request, if there is one
    my ( $barcode, $barcode_field ) = $self->find_item_barcode($request);
    if ($barcode) {
        # We have a barcode (or something passing itself off as a barcode)
        # try to use it to get item data
        $itemdata = GetItem( undef, $barcode );
        unless ( $itemdata ) {
            my $problem = NCIP::Problem->new({
                ProblemType    => 'Unknown Item',
                ProblemDetail  => "Item $barcode is unknown",
                ProblemElement => $barcode_field,
                ProblemValue   => $barcode,
            });
            $response->problem($problem);
            return $response;
        }
    }

    my $cardnumber = _isil2barcode( $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId} );
    my $patron = Koha::Patrons->find({ cardnumber => $cardnumber });

    # Check if renewal is possible
    my ($ok,$error) = CanBookBeRenewed( $patron->borrowernumber, $itemdata->{'itemnumber'} );
    unless ( $ok ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Item Not Renewable',
            ProblemDetail  => 'Item may not be renewed',
            # ProblemElement => 'FIXME',
            # ProblemValue   => 'FIXME',
        });
        $response->problem($problem);
        return $response;
    }

    # Do the actual renewal
    my $datedue = AddRenewal( $patron->borrowernumber, $itemdata->{'itemnumber'} );
    if ( $datedue ) {

        # Check the number of remaning renewals
        my ( $renewcount, $renewsallowed, $renewsleft ) = GetRenewCount( $patron->borrowernumber, $itemdata->{'itemnumber'} );
        # Send the response
        my $data = {
            ItemId => NCIP::Item::Id->new(
                {
                    AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                    ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                    ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue},
                }
            ),
            UserId => NCIP::User::Id->new(
                {
                    UserIdentifierType => 'Barcode Id',
                    UserIdentifierValue => $cardnumber,
                }
            ),
            DateDue      => $datedue,
            fromagencyid => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
            toagencyid   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
            diag         => "renewals: $renewcount, renewals allowed: $renewsallowed, renewals left: $renewsleft",
        };
        $response->data($data);
        return $response;
    } else {
        # The renewal failed
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Item Not Renewable',
            ProblemDetail  => 'Item may not be renewed',
            # ProblemElement => 'FIXME',
            # ProblemValue   => 'FIXME',
        });
        $response->problem($problem);
        return $response;
    }

}

=head2 cancelrequestitem

    $response = $ils->cancelrequestitem($request);

Handle the NCIP CancelRequestItem message.

This can be the result of:

=over 4

=item * the Home library cancelling a RequestItem (#10). Status at the Owner
Library will change from O_REQUESTITEM to DONE.

=item * the Owner library rejecting a RequestItem (#11). Status at the Home
Library will change from H_REQUESTITEM to CANCELLED. This must prompt a librarian
to look into the reasons for cancelleing and deciding whether to make a new
request to another library. After this has been done, the request status should
change from CANCELLED to DONE (but that will be the responsibility of the
NNCIPP ILL backend in Koha).

=back

=cut

sub cancelrequestitem {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Find the request
    my $saved_request = _getRequestByOrderId($request->{$message});

    unless ( $saved_request ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'RequestItem can not be cancelled',
            ProblemDetail  => "Request with id " . $request->{$message}->{RequestId}->{RequestIdentifierValue} . " unknown",
            ProblemElement => 'RequestIdentifierValue',
            ProblemValue   => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        });
        $response->problem($problem);
        return $response;
    }

    # Delete hold if there is one
    if (my $hold_id = $saved_request->illrequestattributes->find({ type => 'KohaReserveId' })->value()) {
        my $hold = Koha::Holds->find($hold_id);
        $hold and $hold->delete(); # silently delete it (should I ->cancel instead?)
    }

    # Check if we are the Owner Library or not
    if ( $saved_request->status eq 'O_REQUESTITEM' ) {
        # We are the Owner Library, so this is #10
        # Set status to DONE and delete hold
        $saved_request->status( 'DONE' )->store;
    } elsif ( $saved_request->status eq 'H_REQUESTITEM' ) {
        # We are the Home Library, so this is #11
        # Set status to H_CANCELLED, delete temporary biblio and item, and delete hold
        $saved_request->status( 'H_CANCELLED' )->store;
        if (my $biblio_id = $saved_request->biblio_id) {
            my $biblio = Koha::Biblios->find({ 'biblionumber' => $biblio_id });
            my $items = $biblio->items;
            while (my $item = $items->next ) {
                C4::Items::DelItem({itemnumber => $item->itemnumber, biblionumber => $biblio_id});
            }
            C4::Biblio::DelBiblio($biblio_id);
        }
    } else {
        # We have some status where the RequestItem can not be cancelled,
        # most likely the request is already shipped from the Owner Library.
        my $problem = NCIP::Problem->new({
            ProblemType    => 'RequestItem can not be cancelled',
            ProblemDetail  => "Request with id " . $request->{$message}->{RequestId}->{RequestIdentifierValue} . " can not be cancelled",
            ProblemElement => 'RequestIdentifierValue',
            ProblemValue   => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        });
        $response->problem($problem);
        return $response;
    }

    my $data = {
        fromagencyid           => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        toagencyid             => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        AgencyId               => $request->{$message}->{RequestId}->{AgencyId},
        RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
        RequestType            => $request->{$message}->{RequestType},
    };

    $response->data($data);
    return $response;

}

# Turn NO-xxxxxxx into xxxxxxx
sub _isil2barcode {

    my ( $s ) = @_;
    return unless $s;
    $s =~ s/^NO-//i;
    return $s;
}

=head2 _get_biblionumber_from_standardnumber

Take an "standard number" like ISBN, ISSN or EAN, normalize it, look it up in
the correct column of biblioitems and return the biblionumber of the first
matching record. Legal types:

=back 4

=item * isbn

=item * issn

=item * ean

=back

Hyphens will be removed, both from the input standard number and from the
numbers stored in the Koha database.

=cut

sub _get_biblionumber_from_standardnumber {

    my ( $type, $value ) = @_;
    my $dbh = C4::Context->dbh();
    my $sth = $dbh->prepare("SELECT biblionumber FROM biblioitems WHERE REPLACE( $type, '-', '' ) LIKE REPLACE( '$value', '-', '')");
    $sth->execute();
    my $data = $sth->fetchrow_hashref;
    if ( $data && $data->{ 'biblionumber' } ) {
        return $data->{ 'biblionumber' };
    } else {
        return undef;
    }

}

=head2 _get_langcode_from_bibliodata

Take a record and pick ut the language code in controlfield 008, position 35-37.

=cut

sub _get_langcode_from_bibliodata {

    my ( $bibliodata ) = @_;

    my $marcxml = GetXmlBiblio ($bibliodata->{'biblionumber'} );
    my $record = MARC::Record->new_from_xml( $marcxml, 'UTF-8' );
    if ( $record->field( '008' ) && $record->field( '008' )->data() ) {
        my $f008 = $record->field( '008' )->data();
        my $lang_code = '   ';
        if ( $f008 ) {
            $lang_code = substr $f008, 35, 3;
        }
        return $lang_code;
    } else {
        return '   ';
    }

}

=head2 _isApprovedForRemoteReserve

Check if material is reservable given various conditions

=cut

sub _isApprovedForRemoteReserve {
    my ($biblionumber) = @_;
    $biblionumber or die "Missing biblionumber";
    my $biblio = Koha::Biblios->find($biblionumber) or die "Missing biblio";
    my $datecreated = $biblio->datecreated;

    my $xml = GetXmlBiblio($biblionumber) or die "Missing XML";
    my $rec = MARC::Record->new_from_xml( $xml, "UTF-8" );

    my ( $mtype, $format );
    if ($rec->field("337")) {
        $mtype = $rec->field("337")->subfield("a");
    }
    if ($rec->field("338")) {
        $format = $rec->field("338")->subfield("a");
    }

    # Conditions
    if ($datecreated && int((time()-str2time($datecreated))/86400) < 90) {                  # Material less than 3 months old
        return 0;
    } elsif ($mtype && $mtype eq "Realia" || $mtype eq "Periodika" || $mtype eq "Andre") {  # Mediatypes Realia and Periodika (except format=CD-ROM)
        return 0 unless $format eq "CD-ROM";
    } elsif ($format && $format =~ /Kortspill|Brettspill|Musikkinstrument|Vinylplate/) {    # Formats Brettspill, kortspill, Vinylplate
        return 0;
    } else {
        return 1;
    }
}

=head2 log_to_ils

    $self->{ils}->log_to_ils( $xml );

We want to keep a log of all NCIP messages in one place - in the ILS. This
function will do that for us.

=cut

sub log_to_ils {

    my ( $self, $type, $xml ) = @_;
    logaction( 'ILL', $type, undef, $xml );

}

1;
