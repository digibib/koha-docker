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
use Dancer ':syntax';

use C4::Biblio;
use C4::Circulation qw { AddRenewal CanBookBeRenewed GetRenewCount };
use C4::Members qw{ GetMember };
use C4::Items qw { AddItem GetItem GetItemsByBiblioitemnumber };
use C4::Reserves qw { CanBookBeReserved CanItemBeReserved AddReserve CancelReserve };
use C4::Log;

use Koha::Illrequests;
use Koha::Illrequest::Config;
use Koha::Libraries;
use Koha::Biblio;
use Koha::Biblios;

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

    # my $library = GetBranchDetail( config->{'isilmap'}->{ $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId} } );
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
    my $Illrequests = Koha::Illrequests->new;
    my $saved_request = $Illrequests->find({
        'orderid' => $request->{$message}->{RequestId}->{AgencyId} . ':' . $request->{$message}->{RequestId}->{RequestIdentifierValue},
    });
    # Check if we are the Home Library or not
    if ( $saved_request->status eq 'H_REQUESTITEM' ) {
        # We are the Home Library and we are being told that the Owner Library
        # has shipped the item we want (or a replacement for it)
        # Find the item
        my $biblio_id = $saved_request->biblio_id or die "no biblio_id on saved_request";
        my $biblio = Koha::Biblios->find({ 'biblionumber' => $biblio_id });
        my @items = $biblio->items();
        @items == 1 or die "expected only 1 entry for $biblio_id, got: ".scalar(@items);
        # There should only be one item, so we grap the first one
        my $item = $items[0];
        if ($request->{$message}->{ItemId}->{ItemIdentifierType} eq "Barcode") {
            my $barcode = $request->{$message}->{ItemId}->{ItemIdentifierValue};
            # TODO: Check if barcode is already in DB
            $item->barcode($barcode);
            $item->store;
        }
        # Place a hold
        my $canReserve = CanItemBeReserved( $saved_request->borrowernumber, $item->itemnumber );
        if ($canReserve eq 'OK') {
            AddReserve(
                'ILL',                               # branch FIXME Should this be not hardcoded? Should it be the branch the book belongs to?
                $saved_request->borrowernumber,  # borrowernumber
                $biblio->biblionumber,               # biblionumber
                undef,                               # bibitems - Not used
                undef,                               # priority
                undef,                               # resdate
                undef,                               # expdate
                'Hold placed by NNCIPP',             # notes
                '',                                  # title
                $item->itemnumber || undef,      # checkitem
                undef,                               # found
                undef,                               # itemtype
            );
        } else {
            warn "Can not place hold: $canReserve";
        }
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
    my $Illrequests = Koha::Illrequests->new;
    my $saved_request = $Illrequests->find({
        'orderid' => $request->{$message}->{RequestId}->{AgencyId} . ':' . $request->{$message}->{RequestId}->{RequestIdentifierValue},
    });
    # Check if we are the Owner Library or not
    if ( $saved_request->status eq 'O_ITEMSHIPPED' ) {
        # We are the Owner Library, so this is #5
        $saved_request->status( 'O_ITEMRECEIVED' )->store;
    } elsif ( $saved_request->status eq 'H_RETURNED' ) {
        # We are the Home Library, so this is #7
        $saved_request->status( 'DONE' )->store;
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

    # Find the cardnumber of the borrower
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

    # Find the library (borrower) based on the FromAgencyId
    my $cardnumber = _isil2barcode( $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId} );
    my $borrower = GetMember( 'cardnumber' => $cardnumber );
    unless ( $borrower ) {
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
    # Save the request
    my $illrequest = Koha::Illrequest->new;
    $illrequest->load_backend( 'NNCIPP' );
    my $backend_result = $illrequest->backend_create({
        'borrowernumber' => $borrower->{borrowernumber},
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
        },
        'stage'          => 'commit',
    });

    # Check if the book (record level) can be reserved
    # TODO: Should we add more logic here?
    my $canReserve = CanBookBeReserved( $borrower->{borrowernumber}, $biblionumber );
    if ($canReserve eq 'OK') {
        AddReserve(
                'ILL',                               # branch FIXME Should this be not hardcoded? Should it be the branch the book belongs to?
                $borrower->{borrowernumber},         # borrowernumber
                $biblionumber,                       # biblionumber
                undef,                               # bibitems - Not used
                undef,                               # priority
                undef,                               # resdate
                undef,                               # expdate
                'Hold placed by NNCIPP',             # notes
                '',                                  # title
                undef,                               # checkitem
                undef,                               # found
                undef,                               # itemtype
            );
    } else {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'ERROR PLACING HOLD',
            ProblemDetail  => 'NULL',
            ProblemElement => 'NULL',
            ProblemValue   => $canReserve,
        });
        $response->problem($problem);
        return $response;
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
        ItemId => NCIP::Item::Id->new(
            {
                ItemIdentifierValue => $biblionumber,
                ItemIdentifierType => 'OwnerLocalRecordID',
            }
        ),
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
                MediumType         => 'Book', # FIXME
            }
        ),
    };

        # Look for UserElements requested and add it to the response:
        # my $elements = $request->{$message}->{UserElementType};
        # if ($elements) {
        #     $elements = [$elements] unless (ref $elements eq 'ARRAY');
        #     my $optionalfields = $self->handle_user_elements($user, $elements);
        #     $data->{UserOptionalFields} = $optionalfields;
        # }
        # $elements = $request->{$message}->{ItemElementType};
        # if ($elements) {
        #     $elements = [$elements] unless (ref($elements) eq 'ARRAY');
        #     my $optionalfields = $self->handle_item_elements($copy_details->{copy}, $elements);
        #     $data->{ItemOptionalFields} = $optionalfields;
        # }

    $response->data($data);
    return $response;

}

=head2 itemrequested

    $response = $ils->itemrequested($request);

Handle the NCIP ItemRequested message.

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

    # Get the ID of library we ordered from
    # Mandatory fields, check they exist first or die
    my $ordered_from = _isil2barcode( $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId} ) // die "Missing valid Agency ID";
    my $ordered_from_patron = GetMember( cardnumber => $ordered_from ) // die "Cannot find Agency Patron in DB: '$ordered_from'";

    my $itemidentifiertype = $request->{$message}->{ItemId}->{ItemIdentifierType} //
        $request->{$message}->{BibliographicId}->{BibliographicRecordId}->{BibliographicRecordIdentifierCode} // die "No valid Item Identifier Type found";
    my $itemidentifiervalue = $request->{$message}->{ItemId}->{ItemIdentifierValue} //
        $request->{$message}->{BibliographicId}->{BibliographicRecordId}->{BibliographicRecordIdentifier} // die "No valid Item Identifier Value found";

    # Create a minimal MARC record based on ItemOptionalFields
    # FIXME This could be done in a more elegant way
    my $bibdata = $request->{$message}->{ItemOptionalFields}->{BibliographicDescription};
    my $xml = '<record>
    <datafield tag="100" ind1=" " ind2=" ">
        <subfield code="a">' . $bibdata->{Author} . '</subfield>
    </datafield>
    <datafield tag="245" ind1=" " ind2=" ">
        <subfield code="a">' . $bibdata->{Title} . '</subfield>
    </datafield>';
    if ( $bibdata->{PlaceOfPublication} || $bibdata->{Publisher} || $bibdata->{PublicationDate} ) {
        $xml .= '<datafield tag="260" ind1=" " ind2=" ">';
            if ( $bibdata->{PlaceOfPublication} ) {
                $xml .= '<subfield code="a">' . $bibdata->{PlaceOfPublication} . '</subfield>';
            }
            if ( $bibdata->{PlaceOfPublication} ) {
                $xml .= '<subfield code="b">' . $bibdata->{Publisher} .          '</subfield>';
            }
            if ( $bibdata->{PlaceOfPublication} ) {
                $xml .= '<subfield code="c">' . $bibdata->{PublicationDate} .    '</subfield>';
            }
        $xml .= '</datafield>';
    }
    $xml .= '</record>';
    my $record = MARC::Record->new_from_xml( $xml, 'UTF-8' );
    my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $record, 'FA' );
    warn "biblionumber $biblionumber created";

    # Add an item
    # FIXME Data should not be hardcoded
    my $item = {
        'homebranch'    => 'ILL',
        'holdingbranch' => 'ILL',
        'itype'         => 'ILL',
    };
    my ( $x_biblionumber, $x_biblioitemnumber, $itemnumber ) = AddItem( $item, $biblionumber );
    warn "itemnumber $itemnumber created";

    # Get the borrower that the request is meant for
    my $cardnumber = $request->{$message}->{UserId}->{UserIdentifierValue};
    my $borrower = GetMember( 'cardnumber' => $cardnumber );

    # Save a new request with the newly created biblionumber
    my $illrequest = Koha::Illrequest->new;
    $illrequest->load_backend( 'NNCIPP' );
    my $backend_result = $illrequest->backend_create({
        'borrowernumber' => $borrower->{borrowernumber},
        'biblionumber'   => $biblionumber,
        'branchcode'     => 'ILL', # FIXME
        'status'         => 'H_ITEMREQUESTED',
        'medium'         => $bibdata->{MediumType},
        'backend'        => 'NNCIPP',
        'attr'           => {
            'title'        => $bibdata->{Title},
            'author'       => $bibdata->{Author},
            'ordered_from' => $ordered_from,
            'ordered_from_borrowernumber' => $ordered_from_patron->{borrowernumber},
            # 'id'           => 1,
            'PlaceOfPublication'  => $bibdata->{PlaceOfPublication},
            'Publisher'           => $bibdata->{Publisher},
            'PublicationDate'     => $bibdata->{PublicationDate},
            'Language'            => $bibdata->{Language},
            'ItemIdentifierType'  => $itemidentifiertype,
            'ItemIdentifierValue' => $itemidentifiervalue,
            'RequestType'         => $request->{$message}->{RequestType},
            'RequestScopeType'    => $request->{$message}->{RequestScopeType},
        },
        'stage'          => 'commit',
    });
    warn Dumper $backend_result;

    # Data for ItemRequestedResponse
    my $data = {
        RequestType  => $message,
        ToAgencyId   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        FromAgencyId => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
        UserId       => $request->{$message}->{UserId}->{UserIdentifierValue},
        ItemId       => $request->{$message}->{ItemId}->{ItemIdentifierValue},
    };

    $response->data($data);
    return $response;

    # This should trigger an immediate RequestItem back to the Owner Library
    # But the server should probably not be the one sending it...

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

    # Find the cardnumber of the borrower
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
        # We have a barcode (or something passing itself off as a barcode), 
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
    my $borrower = GetMember( cardnumber => $cardnumber );

    # Check if renewal is possible
    my ($ok,$error) = CanBookBeRenewed( $borrower->{'borrowernumber'}, $itemdata->{'itemnumber'} );
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
    my $datedue = AddRenewal( $borrower->{'borrowernumber'}, $itemdata->{'itemnumber'} );
    if ( $datedue ) {

        # The renewal was successfull, change the status of the request?

        # Find the request - nah, we don't really need it for anything?
        # my $Illrequests = Koha::Illrequests->new;
        # my $saved_request = $Illrequests->find({
        #     'orderid' => $request->{$message}->{RequestId}->{AgencyId} . ':' . $request->{$message}->{RequestId}->{RequestIdentifierValue},
        # });
        # $saved_request->status( 'O_ITEMRECEIVED' )->store;

        # Check the number of remaning renewals
        my ( $renewcount, $renewsallowed, $renewsleft ) = GetRenewCount( $borrower->{'borrowernumber'}, $itemdata->{'itemnumber'} );
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
    my $Illrequests = Koha::Illrequests->new;
    my $saved_request = $Illrequests->find({
        'orderid' => $request->{$message}->{RequestId}->{AgencyId} . ':' . $request->{$message}->{RequestId}->{RequestIdentifierValue},
    });

    # Unknown request
    # FIXME This should probably be a sub, called from all the NCIP-verb subs
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

    # Check if we are the Owner Library or not
    if ( $saved_request->status eq 'O_REQUESTITEM' ) {
        # We are the Owner Library, so this is #10
        $saved_request->status( 'DONE' )->store;
    } elsif ( $saved_request->status eq 'H_REQUESTITEM' ) {
        # We are the Home Library, so this is #11
        $saved_request->status( 'H_CANCELLED' )->store;
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

sub cancelrequestitem_old {

    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    # FIXME $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # Find the cardnumber of the borrower
    my ( $cardnumber, $cardnumber_field ) = $self->find_user_barcode( $request );
    unless( $cardnumber ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Needed Data Missing',
            ProblemDetail  => 'Cannot find user barcode in message',
            ProblemElement => $cardnumber_field,
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    # Find the borrower based on the cardnumber
    my $borrower = GetMember( 'cardnumber' => $cardnumber );
    unless ( $borrower ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'Unknown User',
            ProblemDetail  => "User with barcode $cardnumber unknown",
            ProblemElement => $cardnumber_field,
            ProblemValue   => 'NULL',
        });
        $response->problem($problem);
        return $response;
    }

    # my $reserve = CancelReserve( { reserve_id => $requestid } );
    # CancelReserve returns data about the reserve on success, undef on failure
    # FIXME We can be more specific about the failure if we check the reserve
    # more in depth before we do CancelReserve, e.g. with GetReserve

    # We need to figure out if this is
    # * the home library cancelling a request it has sent out (NNCIPP call #10)
    # * an owner library rejecting a request it has received (NNCIPP call #11)

    my $remote_id = $request->{$message}->{RequestId}->{AgencyId} . ':' . $request->{$message}->{RequestId}->{RequestIdentifierValue};
    my $Illrequests = Koha::Illrequests->new;
    my $saved_requests = $Illrequests->search({
        'remote_id' => $remote_id,
        'status'    => 'NEW',
    });
    unless ( defined $saved_requests->[0] ) {
        $saved_requests = $Illrequests->search({
            'remote_id' => $remote_id,
            'status'    => 'SHIPPED',
        });
    }
    unless ( defined $saved_requests->[0] ) {
        $saved_requests = $Illrequests->search({
            'remote_id' => $remote_id,
            'status'    => 'ORDERED',
        });
    }
    # There should only be one request, so we use the zero'th one
    my $saved_request = $saved_requests->[0];
    unless ( $saved_request ) {
        my $problem = NCIP::Problem->new({
            ProblemType    => 'RequestItem can not be cancelled',
            ProblemDetail  => "Request with id $remote_id unknown",
            ProblemElement => 'RequestIdentifierValue',
            ProblemValue   => $remote_id,
        });
        $response->problem($problem);
        return $response;
    }

    # FIXME
    if ( $saved_request->status->getProperty('status') eq 'NEW' || $saved_request->status->getProperty('status') eq 'SHIPPED' ) {

        # The request is being cancelled (withdrawn) by the home library

        # Now we check if the request has already been processed or not
        my $data;
        if ( $saved_request->status->getProperty('status') eq 'NEW' ) {

            # Request CAN be cancelled
            $saved_request->editStatus({ 'status' => 'CANCELLED' });
            $data = {
                RequestId => NCIP::RequestId->new(
                    {
                        AgencyId => $request->{$message}->{RequestId}->{AgencyId},
                        RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
                    }
                ),
                UserId => NCIP::User::Id->new(
                    {
                        UserIdentifierValue => $borrower->{'cardnumber'},
                    }
                ),
                ItemId => NCIP::Item::Id->new(
                    {
                        ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                        ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue},
                    }
                ),
                fromagencyid => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
                toagencyid   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
            };

        } else {

            # Request can NOT be cancelled
            $data = {
                Problem => NCIP::Problem->new(
                    {
                        ProblemType   => 'Request Already Processed',
                        ProblemDetail => 'Request cannot be cancelled because it has already been processed.'
                    }
                ),
                RequestId => NCIP::RequestId->new(
                    {
                        AgencyId => $request->{$message}->{RequestId}->{AgencyId},
                        RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
                    }
                ),
                UserId => NCIP::User::Id->new(
                    {
                        UserIdentifierValue => $borrower->{'cardnumber'},
                    }
                ),
                ItemId => NCIP::Item::Id->new(
                    {
                        ItemIdentifierType  => $request->{$message}->{ItemId}->{ItemIdentifierType},
                        ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue},
                    }
                ),
                fromagencyid => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
                toagencyid   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
            };

        }

        # If we got this far, the request was successfully cancelled

        $response->data($data);
        return $response;

    } if ( $saved_request->status->getProperty('status') eq 'ORDERED' ) {

        # The request is being rejected by the owner library

        $saved_request->editStatus({ 'status' => 'REJECTED' });
        my $data = {
            RequestId => NCIP::RequestId->new(
                {
                    AgencyId => $request->{$message}->{RequestId}->{AgencyId},
                    RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue},
                }
            ),
            UserId => NCIP::User::Id->new(
                {
                    UserIdentifierValue => $request->{$message}->{UserId}->{UserIdentifierValue},
                }
            ),
            ItemId => NCIP::Item::Id->new(
                {
                    ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                    ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue},
                }
            ),
            fromagencyid => $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId},
            toagencyid   => $request->{$message}->{InitiationHeader}->{FromAgencyId}->{AgencyId},
        };

        $response->data($data);
        return $response;

    }

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
