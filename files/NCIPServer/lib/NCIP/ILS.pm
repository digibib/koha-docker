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
package NCIP::ILS;

use Modern::Perl;
use NCIP::Const;
use NCIP::Header;
use NCIP::Problem;
use NCIP::Response;
# For find_bibliographic_ids:
use NCIP::Item::BibliographicItemId;
use NCIP::Item::BibliographicRecordId;

=head1 NAME

NCIP::ILS - A base class for NIPServer ILS drivers.

=head1 SYNOPSIS

    use NCIP::ILS;

    $ils = NCIP::ILS->new(name => $config->{NCIP.ils.value});

=head1 DESCRIPTION

NCIP::ILS is meant as a base class and test implementation of the ILS
specific drivers of NCIPServer.  If you wish to implement a driver for
your specific ILS, then it is recommended you subclass this module and
reimplement the methods as necessary.

=cut

sub new {
    my $invocant = shift;
    my $class = ref $invocant || $invocant;
    my $self = bless {@_}, $class;
    return $self;
}

=head1 HANDLER METHODS

When NCIPServer receives an incoming message, it translates the
requested service into lower case and then checks if the ILS has a
method by that name.  If it does that method is called with a single
argument consisting of the XML request converted to a hash ref via
XML::LibXML::Simple.  If the ILS does not support that service, then
the unsupportedservice method of the ILS is called and the resulting
problem response returned to the client.

All handler methods must return a NCIP::Response object.

The handler methods provided in this base class implementation are
those that were required for the initial implemenation of NCIPServer
to be used with a particular initiator software.  You may add any
additional handlers to your implementation as required without needing
to alter this base class.

=cut

# Methods required for SHAREit:

=head2 acceptitem

Called to handle the AcceptItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub acceptitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 cancelrequestitem

Called to handle the CancelRequestItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub cancelrequestitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 checkinitem

Called to handle the CheckInItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub checkinitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 checkoutitem

Called to handle the CheckOutItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub checkoutitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 lookupuser

Called to handle the LookupUser service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub lookupuser {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 renewitem

Called to handle the RenewItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub renewitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

=head2 requestitem

Called to handle the RequestItem service request.  The inherited
implementation returns the Unsupported Service problem response.

=cut

sub requestitem {
    my $self = shift;
    my $request = shift;

    return $self->unsupportedservice($request);
}

# Other methods, just because.

=head2 lookupversion

Called to handle the LookupVersion service request.  The inherited
implementation returns the list of supported versions from
NCIP::Const.  You probably do not want to reimplement this method in
your subclass.

=cut

sub lookupversion {
    my $self = shift;
    my $request = shift;

    my $response = NCIP::Response->new({type => "LookupVersionResponse"});
    my $payload = {
        fromagencyid => $request->{LookupVersion}->{ToAgencyId}->{AgencyId},
        toagencyid => $request->{LookupVersion}->{FromAgencyId}->{AgencyId},
        versions => [ NCIP::Const::SUPPORTED_VERSIONS ]
    };
    $response->data($payload);

    return $response;
}

=head2 lookupagency

Called to handle the LookupAgency service request.

=cut

sub lookupagency {
    my $self = shift;
    my $request = shift;

    my $response = NCIP::Response->new({type => "LookupAgencyResponse"});
    my $payload = {
        fromagencyid => $request->{LookupVersion}->{ToAgencyId}->{AgencyId},
        toagencyid => $request->{LookupVersion}->{FromAgencyId}->{AgencyId},
    };
    $response->data($payload);

    return $response;
}

=head1 USEFUL METHODS

These are methods of the base class that you may want to use in your
subclass or that are used by NCIPserver or other methods of this base
class.  You very likely do not want to override these in your
subclass.

=cut

=head2 unsupportedservice

    $response = $ils->unsupportedservice($request);

This method has the same signature as a regular service handler
method.  It returns a response containing an Unsupported Service
problem.  It is used by NCIP.pm when the ILS cannot handle a message,
or your implementation could return this in the case of a
service/message you don't actually handle, though you may have the
proper function defined.

=cut

sub unsupportedservice {
    my $self = shift;
    my $request = shift;

    my $service = $self->parse_request_type($request);

    my $response = NCIP::Response->new({type => $service . 'Response'});
    my $problem = NCIP::Problem->new();
    $problem->ProblemType('Unsupported Service');
    $problem->ProblemDetail("$service service is not supported by this implementation.");
    $problem->ProblemElement("NULL");
    $problem->ProblemValue("Not Supported");
    $response->problem($problem);

    return $response;
}

=head2 make_header

    $response->header($ils->make_header($request));

All subclasses will possibly want to create a ResponseHeader for the
response message.  Since the code for that could be highly redundant
if reimplemented by each subclass, the base class supplies an
implementation that retrieves the agency information from the
InitiationHeader of the request message, swaps the FromAgencyId with
the ToAgencyId, and vice versa.  It then returns a NCIP::Header to be
used in the NCIP::Response object's header field.

=cut

sub make_header {
    my $self = shift;
    my $request = shift;

    my $initheader;
    my $header;

    my $key = $self->parse_request_type($request);
    $initheader = $request->{$key}->{InitiationHeader}
        if ($key && $request->{$key}->{InitiationHeader});

    if ($initheader && $initheader->{FromAgencyId}
            && $initheader->{ToAgencyId}) {
        $header = NCIP::Header->new({
            FromAgencyId => $initheader->{ToAgencyId},
            ToAgencyId => $initheader->{FromAgencyId}
        });
    }

    return $header;
}

=head2 parse_request_type

    $type = $ils->parse_request_type($request);

Given the request hashref object, parse_request_type will return the
service being requested in the message.  This method is called by
NCIP.pm in order to determine which handler of the ILS object to call.
You may find it convenient to use this method in your own handler
implementations.  You should not need to override this method in your
subclass.

=cut

sub parse_request_type {
    my $self = shift;
    my $request = shift;
    my $type;

    for my $key (keys %$request) {
        if (ref $request->{$key} eq 'HASH') {
            $type = $key;
            last;
        }
    }

    return $type;
}

=head2 find_user_barcode

    $barcode = $ils->find_user_barcode($request);
    ($barcode, $field) = $ils->find_user_barcode($request);

If you have a request type that includes a user barcode identifier
value, this routine will find it.

It will return the barcode in scalar context, or the barcode and the
tag of the field where the barcode was found in list context.

If multiple barcode fields are provided, it returns the first one that
it finds. This is not necessarily the first one given in the request
message. Maybe we should add a plural form of this method to find all
of the user barcodes provided?

=cut

sub find_user_barcode {
    my $self = shift;
    my $request = shift;

    my $barcode;
    my $field;
    my $message = $self->parse_request_type($request);

    # Check for UserId first because it is valid in all messages.
    my $authinput = $request->{$message}->{UserId};
    if ($authinput) {
        $field = 'UserIdentifierValue';
        $barcode = $authinput->{$field};
    } elsif (grep {$_ eq $message} NCIP::Const::AUTHENTICATIONINPUT_MESSAGES) {
        $field = 'AuthenticationInputData';
        $authinput = $request->{$message}->{AuthenticationInput};
        # Convert to array ref if it isn't already.
        if (ref $authinput ne 'ARRAY') {
            $authinput = [$authinput];
        }
        foreach my $input (@$authinput) {
            if ($input->{AuthenticationInputType} && $input->{AuthenticationInputType} =~ /barcode/i) {
                $barcode = $input->{$field};
                last;
            }
        }
    }

    return (wantarray) ? ($barcode, $field) : $barcode;
}

=head2 find_item_barcode

    $barcode = $ils->find_item_barcode($request);
    ($barcode, $field) = $ils->find_item_barcode($request);

If you have a request type that includes an item barcode identifier
value, this routine will find it.

It will return the barcode in scalar context, or the barcode and the
tag of the field where the barcode was found in list context.

If multiple barcode fields are provided, it returns the first one that
it finds. This is not necessarily the first one given in the request
message. Maybe we should add a plural form of this method to find all
of the item barcodes provided?

=cut

sub find_item_barcode {
    my $self = shift;
    my $request = shift;

    my $barcode;
    my $field;
    my $message = $self->parse_request_type($request);

    my $idinput = $request->{$message}->{ItemId};
    if ($idinput) {
        $field = 'ItemIdentifierValue';
        $idinput = [$idinput] unless (ref($idinput) eq 'ARRAY');
        foreach my $input (@$idinput) {
            if ($input->{ItemIdentifierType}) {
                next unless ($input->{ItemIdentifierType} =~ /barcode/i);
            }
            $barcode = $input->{ItemIdentifierValue};
            last if ($barcode);
        }
    }

    return (wantarray) ? ($barcode, $field) : $barcode;
}

=head2 find_bibliographic_ids

    $biblio_ids = $ils->find_bibliographic_ids($request);
    @biblio_ids = $ils->find_bibliographic_ids($request);

Finds the BibliograpicId tags in the request message and returns a
list of NCIP::Item::BibliographicItemId or
NCIP::Item::BibliographicRecordId depending upon which are found in
the request, either or both could be present. If no BibliographicId is
found, then it returns an empty list.

In array context, it returns an array, in scalar context, an array
ref.

=cut

sub find_bibliographic_ids {
    my $self = shift;
    my $request = shift;
    my $idcode = shift;

    # Our return variable, so set this if we find any ids.
    my @ids = ();

    my $message = $self->parse_request_type($request);

    # Find the BibliographicId in the xml.
    my $idxml;
    if ($request->{$message}->{ItemOptionalFields}->{BibligraphicDescription}) {
        $idxml = $request->{$message}->{ItemOptionalFields}->{BibligraphicDescription}->{BibliographicId};
    } elsif ($request->{$message}->{BibliographicDescription}) {
        $idxml = $request->{$message}->{BibliographicDescription}->{BibliographicId};
    } else {
        $idxml = $request->{$message}->{BibliographicId};
    }
    if ($idxml) {
        $idxml = [$idxml] unless (ref($idxml) eq 'ARRAY');
        foreach my $entry (@$idxml) {
            my $id;
            if ($entry->{BibliographicRecordId}) {
                my ($identifier, $agencyid, $code);
                $identifier = $entry->{BibliographicRecordId}->{BibliographicRecordIdentifier};
                $code = $entry->{BibliographicRecordId}->{BibliographicRecordIdentifierCode};
                $agencyid = $entry->{BibliographicRecordId}->{AgencyId};
                $id = NCIP::Item::BibliographicRecordId->new(
                    {
                        BibliographicRecordIdentifier => $identifier,
                        BibliographicRecordIdentifierCode => $code,
                        AgencyId => $agencyid
                    }
                );
            } else {
                my ($identifier, $code);
                $identifier = $entry->{BibliographicItemId}->{BibliographicItemIdentifier};
                $code = $entry->{BibliographicItemId}->{BibliographicItemIdentifierCode};
                $id = NCIP::Item::BibliographicItemId->new(
                    {
                        BibliographicItemIdentifier => $identifier,
                        BibliographicItemIdentifierCode => $code
                    }
                );
            }
            push(@ids, $id);
        }
    }

    return (wantarray) ? @ids : [@ids];
}

1;
