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
package NCIP::ILS::Evergreen;

use Modern::Perl;
use XML::LibXML::Simple qw(XMLin);
use DateTime;
use DateTime::Format::ISO8601;
use Digest::MD5 qw/md5_hex/;
use OpenSRF::System;
use OpenSRF::AppSession;
use OpenSRF::Utils qw/:datetime/;
use OpenSRF::Utils::SettingsClient;
use OpenILS::Utils::Fieldmapper;
use OpenILS::Utils::Normalize qw(clean_marc);
use OpenILS::Application::AppUtils;
use OpenILS::Const qw/:const/;
use MARC::Record;
use MARC::Field;
use MARC::File::XML;
use List::MoreUtils qw/uniq/;
use POSIX qw/strftime/;

# We need a bunch of NCIP::* objects.
use NCIP::Response;
use NCIP::Problem;
use NCIP::User;
use NCIP::User::OptionalFields;
use NCIP::User::AddressInformation;
use NCIP::User::Id;
use NCIP::User::BlockOrTrap;
use NCIP::User::Privilege;
use NCIP::User::PrivilegeStatus;
use NCIP::StructuredPersonalUserName;
use NCIP::StructuredAddress;
use NCIP::ElectronicAddress;
use NCIP::PhysicalAddress;
use NCIP::RequestId;
use NCIP::Item::Id;
use NCIP::Item::OptionalFields;
use NCIP::Item::BibliographicDescription;
use NCIP::Item::BibliographicItemId;
use NCIP::Item::BibliographicRecordId;
use NCIP::Item::Description;

# Inherit from NCIP::ILS.
use parent qw(NCIP::ILS);

=head1 NAME

Evergreen - Evergreen driver for NCIPServer

=head1 SYNOPSIS

    my $ils = NCIP::ILS::Evergreen->new(name => $config->{NCIP.ils.value});

=head1 DESCRIPTION

NCIP::ILS::Evergreen is the default driver for Evergreen and
NCIPServer. It was initially developed to work with Auto-Graphics'
SHAREit software using a subset of an unspecified ILL/DCB profile.

=cut

# Default values we define for things that might be missing in our
# runtime environment or configuration file that absolutely must have
# values.
#
# OILS_NCIP_CONFIG_DEFAULT is the default location to find our
# driver's configuration file.  This location can be overridden by
# setting the path in the OILS_NCIP_CONFIG environment variable.
#
# BIB_SOURCE_DEFAULT is the config.bib_source.id to use when creating
# "short" bibs.  It is used only if no entry is supplied in the
# configuration file.  The provided default is 2, the id of the
# "System Local" source that comes with a default Evergreen
# installation.
use constant {
    OILS_NCIP_CONFIG_DEFAULT => '/openils/conf/oils_ncip.xml',
    BIB_SOURCE_DEFAULT => 2
};

# A common Evergreen code shortcut to use AppUtils:
my $U = 'OpenILS::Application::AppUtils';

# The usual constructor:
sub new {
    my $class = shift;
    $class = ref($class) if (ref $class);

    # Instantiate our parent with the rest of the arguments.  It
    # creates a blessed hashref.
    my $self = $class->SUPER::new(@_);

    # Look for our configuration file, load, and parse it:
    $self->_configure();

    # Bootstrap OpenSRF and prepare some OpenILS components.
    $self->_bootstrap();

    # Initialize the rest of our internal state.
    $self->_init();

    return $self;
}

=head1 HANDLER METHODS

=head2 lookupuser

    $ils->lookupuser($request);

Processes a LookupUser request.

=cut

sub lookupuser {
    my $self = shift;
    my $request = shift;

    # Check our session and login if necessary.
    $self->login() unless ($self->checkauth());

    my $message_type = $self->parse_request_type($request);

    # Let's go ahead and create our response object. We need this even
    # if there is a problem.
    my $response = NCIP::Response->new({type => $message_type . "Response"});
    $response->header($self->make_header($request));

    # Need to parse the request object to get the user barcode.
    my ($barcode, $idfield) = $self->find_user_barcode($request);

    # If we did not find a barcode, then report the problem.
    if (ref($barcode) eq 'NCIP::Problem') {
        $response->problem($barcode);
        return $response;
    }

    # Look up our patron by barcode:
    my $user = $self->retrieve_user_by_barcode($barcode, $idfield);
    if (ref($user) eq 'NCIP::Problem') {
        $response->problem($user);
        return $response;
    }

    # We got the information, so lets fill in our userdata.
    my $userdata = NCIP::User->new();

    # Use the user's main card as the UserId.
    my $id = NCIP::User::Id->new({
        UserIdentifierType => 'Barcode',
        UserIdnetifierValue => $user->card->barcode()
    });
    $userdata->UserId($id);

    # Check if they requested any optional fields and return those.
    my $elements = $request->{$message_type}->{UserElementType};
    if ($elements) {
        $elements = [$elements] unless (ref $elements eq 'ARRAY');
        my $optionalfields = $self->handle_user_elements($user, $elements);
        $userdata->UserOptionalFields($optionalfields);
    }

    $response->data($userdata);

    return $response;
}

=head2 acceptitem

    $ils->acceptitem($request);

Processes an AcceptItem request.

=cut

sub acceptitem {
    my $self = shift;
    my $request = shift;

    # Check our session and login if necessary.
    $self->login() unless ($self->checkauth());

    # Common preparation.
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # We only accept holds for the time being.
    if ($request->{$message}->{RequestedActionType} =~ /^hold\W/i) {
        # We need the item id or we can't do anything at all.
        my ($item_barcode, $item_idfield) = $self->find_item_barcode($request);
        if (ref($item_barcode) eq 'NCIP::Problem') {
            $response->problem($item_barcode);
            return $response;
        }

        # We need to find a patron barcode or we can't look anyone up
        # to place a hold.
        my ($user_barcode, $user_idfield) = $self->find_user_barcode($request, 'UserIdentifierValue');
        if (ref($user_barcode) eq 'NCIP::Problem') {
            $response->problem($user_barcode);
            return $response;
        }
        # Look up our patron by barcode:
        my $user = $self->retrieve_user_by_barcode($user_barcode, $user_idfield);
        if (ref($user) eq 'NCIP::Problem') {
            $response->problem($user);
            return $response;
        }
        # We're doing patron checks before looking for bibliographic
        # information and creating the item because problems with the
        # patron are more likely to occur.
        my $problem = $self->check_user_for_problems($user, 'HOLD');
        if ($problem) {
            $response->problem($problem);
            return $response;
        }

        # Check if the item barcode already exists:
        my $item = $self->retrieve_copy_details_by_barcode($item_barcode);
        if ($item) {
            # What to do here was not defined in the
            # specification. Since the copies that we create this way
            # should get deleted when checked in, it would be an error
            # if we try to create another one. It means that something
            # has gone wrong somewhere.
            $response->problem(
                NCIP::Problem->new(
                    {
                        ProblemType => 'Duplicate Item',
                        ProblemDetail => "Item with barcode $item_barcode already exists.",
                        ProblemElement => $item_idfield,
                        ProblemValue => $item_barcode
                    }
                )
            );
            return $response;
        }

        # Now, we have to create our new copy and/or bib and call number.

        # First, we have to gather the necessary information from the
        # request.  Store in a hashref for convenience. We may write a
        # method to get this information in the future if we find we
        # need it in other handlers. Such a function would be a
        # candidate to go into our parent, NCIP::ILS.
        my $item_info = {
            barcode => $item_barcode,
            call_number => $request->{$message}->{ItemOptionalFields}->{ItemDescription}->{CallNumber},
            title => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{Title},
            author => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{Author},
            publisher => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{Publisher},
            publication_date => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{PublicationDate},
            medium => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{MediumType},
            electronic => $request->{$message}->{ItemOptionalFields}->{BibliographicDescription}->{ElectronicResource}
        };

        if ($self->{config}->{items}->{use_precats}) {
            # We only need to create a precat copy.
            $item = $self->create_precat_copy($item_info);
        } else {
            # We have to create a "partial" bib record, a call number and a copy.
            $item = $self->create_fuller_copy($item_info);
        }

        # If we failed to create the copy, report a problem.
        unless ($item) {
            $response->problem(
                {
                    ProblemType => 'Temporary Processing Failure',
                    ProblemDetail => 'Failed to create the item in the system',
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            );
            return $response;
        }

        # We try to find the pickup location in our database. It's OK
        # if it does not exist, the user's home library will be used
        # instead.
        my $location = $self->find_location_failover($request->{$message}->{PickupLocation}, $request, $message);

        # Now, we place the hold on the newly created copy on behalf
        # of the patron retrieved above.
        my $hold = $self->place_hold($item, $user, $location);
        if (ref($hold) eq 'NCIP::Problem') {
            $response->problem($hold);
            return $response;
        }

        # We return the RequestId and optionally, the ItemID. We'll
        # just return what was sent to us, since we ignored all of it
        # but the barcode.
        my $data = {};
        $data->{RequestId} = NCIP::RequestId->new(
            {
                AgencyId => $request->{$message}->{RequestId}->{AgencyId},
                RequestIdentifierType => $request->{$message}->{RequestId}->{RequestIdentifierType},
                RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue}
            }
        );
        $data->{ItemId} = NCIP::Item::Id->new(
            {
                AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue}
            }
        );
        $response->data($data);

    } else {
        my $problem = NCIP::Problem->new();
        $problem->ProblemType('Unauthorized Combination Of Element Values For System');
        $problem->ProblemDetail('We only support Hold For Pickup');
        $problem->ProblemElement('RequestedActionType');
        $problem->ProblemValue($request->{$message}->{RequestedActionType});
        $response->problem($problem);
    }

    return $response;
}

=head2 checkinitem

    $response = $ils->checkinitem($request);

Checks the item in if we can find the barcode in the message. It
returns problems if it cannot find the item in the system or if the
item is not checked out.

It could definitely use some more brains at some point as it does not
fully support everything that the standard allows. It also does not
really check if the checkin succeeded or not.

=cut

sub checkinitem {
    my $self = shift;
    my $request = shift;

    # Check our session and login if necessary:
    $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # We need the copy barcode from the message.
    my ($item_barcode, $item_idfield) = $self->find_item_barcode($request);
    if (ref($item_barcode) eq 'NCIP::Problem') {
        $response->problem($item_barcode);
        return $response;
    }

    # Retrieve the copy details.
    my $details = $self->retrieve_copy_details_by_barcode($item_barcode);
    unless ($details) {
        # Return an Unknown Item problem unless we find the copy.
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Unknown Item',
                    ProblemDetail => "Item with barcode $item_barcode is not known.",
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            )
        );
        return $response;
    }

    # Check if a UserId was provided. If so, this is the patron to
    # whom the copy should be checked out.
    my $user;
    my ($user_barcode, $user_idfield) = $self->find_user_barcode($request);
    # We ignore the problem, because the UserId is optional.
    if (ref($user_barcode) ne 'NCIP::Problem') {
        $user = $self->retrieve_user_by_barcode($user_barcode, $user_idfield);
        # We don't ignore a problem here, however.
        if (ref($user) eq 'NCIP::Problem') {
            $response->problem($user);
            return $response;
        }
    }

    # Isolate the copy.
    my $copy = $details->{copy};

    # Look for a circulation and examine its information:
    my $circ = $details->{circ};

    # Check the circ details to see if the copy is checked out and, if
    # the patron was provided, that it is checked out to the patron in
    # question. We also verify the copy ownership and circulation
    # location.
    my $problem = $self->check_circ_details($circ, $copy, $user);
    if ($problem) {
        # We need to fill in some information, however.
        if (!$problem->ProblemValue() && !$problem->ProblemElement()) {
            $problem->ProblemValue($user_barcode);
            $problem->ProblemElement($user_idfield);
        } elsif (!$problem->ProblemElement()) {
            $problem->ProblemElement($item_idfield);
        }
        $response->problem($problem);
        return $response;
    }

    # Checkin parameters. We want to skip hold targeting or making
    # transits, to force the checkin despite the copy status, as
    # well as void overdues.
    my $params = {
        copy_barcode => $copy->barcode(),
        force => 1,
        noop => 1,
        void_overdues => 1
    };
    my $result = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.checkin.override',
        $self->{session}->{authtoken},
        $params
    );
    if (ref($result) eq 'ARRAY') {
        $result = $result->[0];
    }
    if ($result->{textcode} eq 'SUCCESS') {
        # Delete the copy. Since delete_copy checks ownership
        # before attempting to delete the copy, we don't bother
        # checking who owns it.
        $self->delete_copy($copy);
        # We need the circulation user for the information below, so we retrieve it.
        my $circ_user = $self->retrieve_user_by_id($circ->usr());
        my $data = {
            ItemId => NCIP::Item::Id->new(
                {
                    AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                    ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                    ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue}
                }
            ),
            UserId => NCIP::User::Id->new(
                {
                    UserIdentifierType => 'Barcode Id',
                    UserIdentifierValue => $circ_user->card->barcode()
                }
            )
        };

        # Look for UserElements requested and add it to the response:
        my $elements = $request->{$message}->{UserElementType};
        if ($elements) {
            $elements = [$elements] unless (ref $elements eq 'ARRAY');
            my $optionalfields = $self->handle_user_elements($circ_user, $elements);
            $data->{UserOptionalFields} = $optionalfields;
        }
        $elements = $request->{$message}->{ItemElementType};
        if ($elements) {
            $elements = [$elements] unless (ref $elements eq 'ARRAY');
            my $optionalfields = $self->handle_item_elements($copy, $elements);
            $data->{ItemOptionalFields} = $optionalfields;
        }

        $response->data($data);

        # At some point in the future, we should probably check if
        # they requested optional user or item elements and return
        # those. For the time being, we ignore those at the risk of
        # being considered non-compliant.
    } else {
        $response->problem(_problem_from_event('Checkin Failed', $result));
    }

    return $response
}

=head2 renewitem

    $response = $ils->renewitem($request);

Handle the RenewItem message.

=cut

sub renewitem {
    my $self = shift;
    my $request = shift;

    # Check our session and login if necessary:
    $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # We need the copy barcode from the message.
    my ($item_barcode, $item_idfield) = $self->find_item_barcode($request);
    if (ref($item_barcode) eq 'NCIP::Problem') {
        $response->problem($item_barcode);
        return $response;
    }

    # Retrieve the copy details.
    my $details = $self->retrieve_copy_details_by_barcode($item_barcode);
    unless ($details) {
        # Return an Unknown Item problem unless we find the copy.
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Unknown Item',
                    ProblemDetail => "Item with barcode $item_barcode is not known.",
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            )
        );
        return $response;
    }

    # User is required for RenewItem.
    my ($user_barcode, $user_idfield) = $self->find_user_barcode($request);
    if (ref($user_barcode) eq 'NCIP::Problem') {
        $response->problem($user_barcode);
        return $response;
    }
    my $user = $self->retrieve_user_by_barcode($user_barcode, $user_idfield);
    if (ref($user) eq 'NCIP::Problem') {
        $response->problem($user);
        return $response;
    }

    # Isolate the copy.
    my $copy = $details->{copy};

    # Look for a circulation and examine its information:
    my $circ = $details->{circ};

    # Check the circ details to see if the copy is checked out and, if
    # the patron was provided, that it is checked out to the patron in
    # question. We also verify the copy ownership and circulation
    # location.
    my $problem = $self->check_circ_details($circ, $copy, $user);
    if ($problem) {
        # We need to fill in some information, however.
        if (!$problem->ProblemValue() && !$problem->ProblemElement()) {
            $problem->ProblemValue($user_barcode);
            $problem->ProblemElement($user_idfield);
        } elsif (!$problem->ProblemElement()) {
            $problem->ProblemElement($item_idfield);
        }
        $response->problem($problem);
        return $response;
    }

    # Check if user is blocked from renewals:
    $problem = $self->check_user_for_problems($user, 'RENEW');
    if ($problem) {
        # Replace the ProblemElement and ProblemValue fields.
        $problem->ProblemElement($user_idfield);
        $problem->ProblemValue($user_barcode);
        $response->problem($problem);
        return $response;
    }

    # Check if the duration rule allows renewals. It should have been
    # fleshed during the copy details retrieve.
    my $rule = $circ->duration_rule();
    unless (ref($rule)) {
        $rule = $U->simplereq(
            'open-ils.pcrud',
            'open-ils.pcrud.retrieve.crcd',
            $self->{session}->{authtoken},
            $rule
        )->gather(1);
    }
    if ($rule->max_renewals() < 1) {
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Item Not Renewable',
                    ProblemDetail => 'Item may not be renewed.',
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            )
        );
        return $response;
    }

    # Check if there are renewals remaining on the latest circ:
    if ($circ->renewal_remaining() < 1) {
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Maximum Renewals Exceeded',
                    ProblemDetail => 'Renewal cannot proceed because the User has already renewed the Item the maximum number of times permitted.',
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            )
        );
        return $response;
    }

    # Now, we attempt the renewal. If it fails, we simply say that the
    # user is not allowed to renew this item, without getting into
    # details.
    my $params = {
        copy_id => $copy->id(),
        patron_id => $user->id(),
        sip_renewal => 1
    };
    my $r = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.renew.override',
        $self->{session}->{authtoken},
        $params
    )->gather(1);

    # We only look at the first one, since more than one usually means
    # failure.
    if (ref($r) eq 'ARRAY') {
        $r = $r->[0];
    }
    if ($r->{textcode} ne 'SUCCESS') {
        $problem = _problem_from_event('Renewal Failed', $r);
        $response->problem($problem);
    } else {
        my $data = {
            ItemId => NCIP::Item::Id->new(
                {
                    AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                    ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                    ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue}
                }
            ),
            UserId => NCIP::User::Id->new(
                {
                    UserIdentifierType => 'Barcode Id',
                    UserIdentifierValue => $user->card->barcode()
                }
            )
        };
        # We need to retrieve the copy details again to refresh our
        # circ information to get the new due date.
        $details = $self->retrieve_copy_details_by_barcode($item_barcode);
        $circ = $details->{circ};
        $data->{DateDue} = _fix_date($circ->due_date());

        # Look for UserElements requested and add it to the response:
        my $elements = $request->{$message}->{UserElementType};
        if ($elements) {
            $elements = [$elements] unless (ref $elements eq 'ARRAY');
            my $optionalfields = $self->handle_user_elements($user, $elements);
            $data->{UserOptionalFields} = $optionalfields;
        }
        $elements = $request->{$message}->{ItemElementType};
        if ($elements) {
            $elements = [$elements] unless (ref $elements eq 'ARRAY');
            my $optionalfields = $self->handle_item_elements($details->{copy}, $elements);
            $data->{ItemOptionalFields} = $optionalfields;
        }

        $response->data($data);
    }

    # At some point in the future, we should probably check if
    # they requested optional user or item elements and return
    # those. For the time being, we ignore those at the risk of
    # being considered non-compliant.

    return $response;
}

=head2 checkoutitem

    $response = $ils->checkoutitem($request);

Handle the Checkoutitem message.

=cut

sub checkoutitem {
    my $self = shift;
    my $request = shift;

    # Check our session and login if necessary:
    $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # We need the copy barcode from the message.
    my ($item_barcode, $item_idfield) = $self->find_item_barcode($request);
    if (ref($item_barcode) eq 'NCIP::Problem') {
        $response->problem($item_barcode);
        return $response;
    }

    # Retrieve the copy details.
    my $details = $self->retrieve_copy_details_by_barcode($item_barcode);
    unless ($details) {
        # Return an Unknown Item problem unless we find the copy.
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Unknown Item',
                    ProblemDetail => "Item with barcode $item_barcode is not known.",
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            )
        );
        return $response;
    }

    # User is required for CheckOutItem.
    my ($user_barcode, $user_idfield) = $self->find_user_barcode($request);
    if (ref($user_barcode) eq 'NCIP::Problem') {
        $response->problem($user_barcode);
        return $response;
    }
    my $user = $self->retrieve_user_by_barcode($user_barcode, $user_idfield);
    if (ref($user) eq 'NCIP::Problem') {
        $response->problem($user);
        return $response;
    }

    # Isolate the copy.
    my $copy = $details->{copy};

    # Check if the copy can circulate.
    unless ($self->copy_can_circulate($copy)) {
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Item Does Not Circulate',
                    ProblemDetail => "Item with barcode $item_barcode does not circulate.",
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            )
        );
        return $response;
    }

    # Look for a circulation and examine its information:
    my $circ = $details->{circ};

    # Check if the item is already checked out.
    if ($circ && !$circ->checkin_time()) {
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Item Already Checked Out',
                    ProblemDetail => "Item with barcode $item_barcode is already checked out.",
                    ProblemElement => $item_idfield,
                    ProblemValue => $item_barcode
                }
            )
        );
        return $response;
    }

    # Check if user is blocked from circulation:
    my $problem = $self->check_user_for_problems($user, 'CIRC');
    if ($problem) {
        # Replace the ProblemElement and ProblemValue fields.
        $problem->ProblemElement($user_idfield);
        $problem->ProblemValue($user_barcode);
        $response->problem($problem);
        return $response;
    }

    # Check for the copy being in transit and receive or abort it.
    my $transit = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.open_copy_transit.retrieve',
        $self->{session}->{authtoken},
        $copy->id()
    );
    if (ref($transit) eq 'Fieldmapper::action::transit_copy') {
        if ($transit->dest() == $self->{session}->{work_ou}->id()) {
            my $r = $U->simplereq(
                'open-ils.circ',
                'open-ils.circ.copy_transit.receive',
                $self->{session}->{authtoken},
                {copyid => $copy->id()}
            );
        } elsif ($transit->source() == $self->{session}->{work_ou}->id()) {
            my $r = $U->simplereq(
                'open-ils.circ',
                'open-ils.circ.transit.abort',
                $self->{session}->{authtoken},
                {copyid => $copy->id()}
            );
        }
    }

    # Now, we attempt the check out. If it fails, we simply say that
    # the user is not allowed to check out this item, without getting
    # into details.
    my $params = {
        copy_id => $copy->id(),
        patron_id => $user->id(),
    };
    my $r = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.checkout.full.override',
        $self->{session}->{authtoken},
        $params
    );

    # We only look at the first one, since more than one usually means
    # failure.
    if (ref($r) eq 'ARRAY') {
        $r = $r->[0];
    }
    if ($r->{textcode} ne 'SUCCESS') {
        $problem = _problem_from_event('Check Out Failed', $r);
        $response->problem($problem);
    } else {
        my $data = {
            ItemId => NCIP::Item::Id->new(
                {
                    AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                    ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                    ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue}
                }
            ),
            UserId => NCIP::User::Id->new(
                {
                    UserIdentifierType => 'Barcode Id',
                    UserIdentifierValue => $user->card->barcode()
                }
            )
        };
        # We need to retrieve the copy details again to refresh our
        # circ information to get the due date.
        $details = $self->retrieve_copy_details_by_barcode($item_barcode);
        $circ = $details->{circ};
        $data->{DateDue} = _fix_date($circ->due_date());

        # Look for UserElements requested and add it to the response:
        my $elements = $request->{$message}->{UserElementType};
        if ($elements) {
            $elements = [$elements] unless (ref $elements eq 'ARRAY');
            my $optionalfields = $self->handle_user_elements($user, $elements);
            $data->{UserOptionalFields} = $optionalfields;
        }
        $elements = $request->{$message}->{ItemElementType};
        if ($elements) {
            $elements = [$elements] unless (ref $elements eq 'ARRAY');
            my $optionalfields = $self->handle_item_elements($details->{copy}, $elements);
            $data->{ItemOptionalFields} = $optionalfields;
        }

        $response->data($data);
    }

    # At some point in the future, we should probably check if
    # they requested optional user or item elements and return
    # those. For the time being, we ignore those at the risk of
    # being considered non-compliant.

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
    $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # We originally had a mass of complicated code here to handle most
    # of the possibilities provided by the standard.  However, that
    # proved too difficult to get working with what we've agreed to do
    # with Auto-Graphics.  The response was supposed to include the
    # ItemId, and for some reason that I couldn't figure out it was
    # not there.  In order to get this working, I've decided to ignor
    # the extra stuff in the standard and just go with what our
    # current vendor sends.

    # Because we need to have a user to place a hold, because the user
    # is likely to have problems, and because getting the item
    # information for the hold is trickier than getting the user
    # information, we'll do the user first and short circuit out of
    # the function if there is a problem with the user.
    my ($user_barcode, $user_idfield) = $self->find_user_barcode($request);
    if (ref($user_barcode) eq 'NCIP::Problem') {
        $response->problem($user_barcode);
        return $response;
    }
    my $user = $self->retrieve_user_by_barcode($user_barcode, $user_idfield);
    if (ref($user) eq 'NCIP::Problem') {
        $response->problem($user);
        return $response;
    }
    my $problem = $self->check_user_for_problems($user, 'HOLD');
    if ($problem) {
        $response->problem($problem);
        return $response;
    }

    # Auto-Graphics send a single BibliographicRecordId to identify
    # the "item" to place on hold.
    my $bibid;
    if ($request->{$message}->{BibliographicId}) {
        my $idxml = $request->{$message}->{BibliographicId};
        # The standard allows more than 1.  If that hapens, we only
        # use the first.
        $idxml = $idxml->[0] if (ref($idxml) eq 'ARRAY');
        if ($idxml->{BibliographicRecordId}) {
            $bibid = NCIP::Item::BibliographicRecordId->new(
                $idxml->{BibliographicRecordId}
            );
        }
    }
    unless ($bibid && $bibid->{BibliographicRecordIdentifier}) {
        $problem = NCIP::Problem->new(
            {
                ProblemType => 'Needed Data Missing',
                ProblemDetail => 'Need BibliographicRecordIdentifier to place request',
                ProblemElement => 'BibliographicRecordIdentifier',
                ProblemValue => 'NULL'
            }
        );
        $response->problem($problem);
        return $response;
    }

    # We need an actual bre.
    my $bre = $self->retrieve_biblio_record_entry($bibid->{BibliographicRecordIdentifier});
    if (!$bre || $U->is_true($bre->deleted())) {
        $problem = NCIP::Problem->new(
            {
                ProblemType => 'Unknown Item',
                ProblemDetail => 'Item ' . $bibid->{BibliographicRecordIdentifier} . ' is unknown',
                ProblemElement => 'BibliographicRecordIdentifier',
                ProblemValue => $bibid->{BibliographicRecordIdentifier}
            }
        );
        $response->problem($problem);
        return $response;
    }

    # Auto-Graphics expects us to limit the selection ou for the hold
    # to a given library.  We look fo that in the AgencyId of the
    # BibliographRecordId or in the ToAgencyId of the main message.
    my $selection_ou = $self->find_location_failover($bibid->{AgencyId}, $request, $message);

    # We need to see if the bib exists and has a holdable, not deleted
    # copy at the selection_ou.  If successful, we retun a
    # copy_details hashref for the holdable copy.
    my $copy_details = $self->find_target_details_by_bre($bre, $selection_ou);
    unless ($copy_details) {
        # We don't know if the items do not circulate or are not
        # holdable, but the closest "standard" problem message is Item
        # Does Not Circulate.
        $problem = NCIP::Problem->new(
            {
                ProblemType => 'Item Does Not Circulate',
                ProblemDetail => 'Request of Item cannot proceed because the Item is non-circulating',
                ProblemElement => 'BibliographicRecordIdentifier',
                ProblemValue => $bre->id()
            }
        );
        $response->problem($problem);
        return $response;
    }

    # See if we were given a pickup location.
    my $pickup_ou;
    if ($request->{$message}->{PickupLocation}) {
        my $loc = $request->{$message}->{PickupLocation};
        $loc =~ s/^.*://;
        $pickup_ou = $self->retrieve_org_unit_by_shortname($loc);
    }

    # Look for a NeedBeforeDate to set the expiration.
    my $expiration = $request->{$message}->{NeedBeforeDate};

    # Place the hold:
    my $hold = $self->place_hold($bre, $user, $pickup_ou, $expiration, $selection_ou);
    if (ref($hold) eq 'NCIP::Problem') {
        $response->problem($hold);
    } else {
        my $data = {
            RequestId => NCIP::RequestId->new(
                $request->{$message}->{RequestId}
            ),
            ItemId => NCIP::Item::Id->new(
                {
                    AgencyId => $selection_ou->shortname(),
                    ItemIdentifierValue => $bre->id(),
                    ItemIdentifierType => 'SYSNUMBER'
                }
            ),
            UserId => NCIP::User::Id->new(
                {
                    UserIdentifierValue => $user->card->barcode(),
                    UserIdentifierType => 'Barcode Id'
                }
            ),
            RequestType => $request->{$message}->{RequestType},
            RequestScopeType => $request->{$message}->{RequestScopeType},
        };

        # Look for UserElements requested and add it to the response:
        my $elements = $request->{$message}->{UserElementType};
        if ($elements) {
            $elements = [$elements] unless (ref $elements eq 'ARRAY');
            my $optionalfields = $self->handle_user_elements($user, $elements);
            $data->{UserOptionalFields} = $optionalfields;
        }
        $elements = $request->{$message}->{ItemElementType};
        if ($elements) {
            $elements = [$elements] unless (ref($elements) eq 'ARRAY');
            my $optionalfields = $self->handle_item_elements($copy_details->{copy}, $elements);
            $data->{ItemOptionalFields} = $optionalfields;
        }

        $response->data($data);
    }

    return $response;
}

=head2 cancelrequestitem

    $response = $ils->cancelrequestitem($request);

Handle the NCIP CancelRequestItem message.

=cut

sub cancelrequestitem {
    my $self = shift;
    my $request = shift;
    # Check our session and login if necessary:
    $self->login() unless ($self->checkauth());

    # Common stuff:
    my $message = $self->parse_request_type($request);
    my $response = NCIP::Response->new({type => $message . 'Response'});
    $response->header($self->make_header($request));

    # UserId is required by the standard, but we might not really need it.
    my ($user_barcode, $user_idfield) = $self->find_user_barcode($request);
    if (ref($user_barcode) eq 'NCIP::Problem') {
        $response->problem($user_barcode);
        return $response;
    }
    my $user = $self->retrieve_user_by_barcode($user_barcode, $user_idfield);
    if (ref($user) eq 'NCIP::Problem') {
        $response->problem($user);
        return $response;
    }

    # Auto-Graphics has agreed to return the ItemId that we sent them
    # in the RequestItemResponse when they attempt CancelRequestItem
    # for that same request.  For the sake of time, we're only going
    # to support that method of looking up the hold request in
    # Evergreen.  We leave it as future enhancement to make this
    # "portable" to other vendors.  (Frankly, that's a fool's errand.
    # NCIP is one of those "standards" where you neeed a separate
    # implementation for every vendor.)
    my $item_id = $request->{$message}->{ItemId};
    unless ($item_id) {
        # We'll throw a problem that we're missing needed information.
        my $problem = NCIP::Problem->new();
        $problem->ProblemType('Needed Data Missing');
        $problem->ProblemDetail('Cannot find ItemId in message.');
        $problem->ProblemElement('ItemId');
        $problem->ProblemValue('NULL');
        $response->problem($problem);
        return $response;
    }
    my $idvalue = $item_id->{ItemIdentifierValue};
    my $itemagy = $item_id->{AgencyId};
    my $selection_ou = $self->find_location_failover($itemagy, $request, $message);
    # We should support looking up holds by barcode, since we still
    # support placing them by barcode, but that is not how it is going
    # to work with Auto-Graphics, apparently.  I'll leave the
    # reimplementation of that for a future enhancement.

    # See if we can find the hold:
    my $hold = $self->_hold_search($user, $idvalue, $selection_ou);
    if ($hold && $hold->transit()) {
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Request Already Processed',
                    ProblemDetail => 'Request has already been processed',
                    ProblemElement => 'RequestIdentifierValue',
                    ProblemValue => $request->{message}->{RequestId}->{RequestIdentifierValue}
                }
            )
       );
    } elsif ($hold) {
        $self->cancel_hold($hold);
        my $data = {
            RequestId => NCIP::RequestId->new(
                {
                    AgencyId => $request->{$message}->{RequestId}->{AgencyId},
                    RequestIdentifierType => $request->{$message}->{RequestId}->{RequestIdentifierType},
                    RequestIdentifierValue => $request->{$message}->{RequestId}->{RequestIdentifierValue}
                }
            ),
            UserId => NCIP::User::Id->new(
                {
                    UserIdentifierType => 'Barcode Id',
                    UserIdentifierValue => $user->card->barcode()
                }
            ),
            ItemId => NCIP::Item::Id->new(
                {
                    AgencyId => $request->{$message}->{ItemId}->{AgencyId},
                    ItemIdentifierType => $request->{$message}->{ItemId}->{ItemIdentifierType},
                    ItemIdentifierValue => $request->{$message}->{ItemId}->{ItemIdentifierValue}
                }
            )
        };
        # Look for UserElements requested and add it to the response:
        my $elements = $request->{$message}->{UserElementType};
        if ($elements) {
            $elements = [$elements] unless (ref $elements eq 'ARRAY');
            my $optionalfields = $self->handle_user_elements($user, $elements);
            $data->{UserOptionalFields} = $optionalfields;
        }
        $elements = $request->{$message}->{ItemElementType};
        if ($elements && $hold->current_copy()) {
            $elements = [$elements] unless (ref $elements eq 'ARRAY');
            my $copy_details = $self->retrieve_copy_details_by_id($hold->current_copy());
            if ($copy_details) {
                my $optionalfields = $self->handle_item_elements($copy_details->{copy}, $elements);
                $data->{ItemOptionalFields} = $optionalfields;
            }
        }
        $response->data($data);
    } else {
        $response->problem(
            NCIP::Problem->new(
                {
                    ProblemType => 'Unknown Request',
                    ProblemDetail => 'No request found for the item and user',
                    ProblemElement => 'NULL',
                    ProblemValue => 'NULL'
                }
            )
        )
    }

    return $response;
}

=head1 METHODS USEFUL to SUBCLASSES

=head2 handle_user_elements
    $useroptionalfield = $ils->handle_user_elements($user, $elements);

Returns NCIP::User::OptionalFields for the given user and arrayref of
UserElement.

=cut

sub handle_user_elements {
    my $self = shift;
    my $user = shift;
    my $elements = shift;
    my $optionalfields = NCIP::User::OptionalFields->new();

    # First, we'll look for name information.
    if (grep {$_ eq 'Name Information'} @$elements) {
        my $name = NCIP::StructuredPersonalUserName->new();
        $name->Surname($user->family_name());
        $name->GivenName($user->first_given_name());
        $name->Prefix($user->prefix());
        $name->Suffix($user->suffix());
        $optionalfields->NameInformation($name);
    }

    # Next, check for user address information.
    if (grep {$_ eq 'User Address Information'} @$elements) {
        my $addresses = [];

        # See if the user has any valid, physcial addresses.
        foreach my $addr (@{$user->addresses()}) {
            next if ($U->is_true($addr->pending()));
            my $address = NCIP::User::AddressInformation->new({UserAddressRoleType=>$addr->address_type()});
            my $structured = NCIP::StructuredAddress->new();
            $structured->Line1($addr->street1());
            $structured->Line2($addr->street2());
            $structured->Locality($addr->city());
            $structured->Region($addr->state());
            $structured->PostalCode($addr->post_code());
            $structured->Country($addr->country());
            $address->PhysicalAddress(
                NCIP::PhysicalAddress->new(
                    {
                        StructuredAddress => $structured,
                        Type => 'Postal Address'
                    }
                )
            );
            push @$addresses, $address;
        }

        # Right now, we're only sharing email address if the user
        # has it.
        if ($user->email()) {
            my $address = NCIP::User::AddressInformation->new({UserAddressRoleType=>'Email Address'});
            $address->ElectronicAddress(
                NCIP::ElectronicAddress->new({
                    Type=>'mailto',
                    Data=>$user->email()
                })
                );
            push @$addresses, $address;
        }
        # Auto-graphics asked for the phone numbers.
        if ($user->day_phone()) {
            my $address = NCIP::User::AddressInformation->new({UserAddressRoleType=>'Day Phone'});
            $address->ElectronicAddress(
                NCIP::ElectronicAddress->new(
                    {
                        Type=>'Day Phone',
                        Data=>$user->day_phone()
                    }
                )
            );
            push @$addresses, $address;
        }
        if ($user->evening_phone()) {
            my $address = NCIP::User::AddressInformation->new({UserAddressRoleType=>'Evening Phone'});
            $address->ElectronicAddress(
                NCIP::ElectronicAddress->new(
                    {
                        Type=>'Evening Phone',
                        Data=>$user->evening_phone()
                    }
                )
            );
            push @$addresses, $address;
        }
        if ($user->other_phone()) {
            my $address = NCIP::User::AddressInformation->new({UserAddressRoleType=>'Other Phone'});
            $address->ElectronicAddress(
                NCIP::ElectronicAddress->new(
                    {
                        Type=>'Other Phone',
                        Data=>$user->other_phone()
                    }
                )
            );
            push @$addresses, $address;
        }

        $optionalfields->UserAddressInformation($addresses);
    }

    # Check for User Privilege.
    if (grep {$_ eq 'User Privilege'} @$elements) {
        # Get the user's group:
        my $pgt = $U->simplereq(
            'open-ils.pcrud',
            'open-ils.pcrud.retrieve.pgt',
            $self->{session}->{authtoken},
            $user->profile()
        );
        if ($pgt) {
            my $privilege = NCIP::User::Privilege->new();
            $privilege->AgencyId($user->home_ou->shortname());
            $privilege->AgencyUserPrivilegeType($pgt->name());
            $privilege->ValidToDate(_fix_date($user->expire_date()));
            $privilege->ValidFromDate(_fix_date($user->create_date()));

            my $status = 'Active';
            if (_expired($user)) {
                $status = 'Expired';
            } elsif ($U->is_true($user->barred())) {
                $status = 'Barred';
            } elsif (!$U->is_true($user->active())) {
                $status = 'Inactive';
            }
            if ($status) {
                $privilege->UserPrivilegeStatus(
                    NCIP::User::PrivilegeStatus->new({
                        UserPrivilegeStatusType => $status
                    })
                );
            }

            $optionalfields->UserPrivilege([$privilege]);
        }
    }

    # Check for Block Or Trap.
    if (grep {$_ eq 'Block Or Trap'} @$elements) {
        my $blocks = [];

        # First, let's check if the profile is blocked from ILL.
        if (grep {$_->id() == $user->profile()} @{$self->{blocked_profiles}}) {
            my $block = NCIP::User::BlockOrTrap->new();
            $block->AgencyId($user->home_ou->shortname());
            $block->BlockOrTrapType('Block Interlibrary Loan');
            push @$blocks, $block;
        }

        # Next, we loop through the user's standing penalties
        # looking for blocks on CIRC, HOLD, and RENEW.
        my ($have_circ, $have_renew, $have_hold) = (0,0,0);
        foreach my $penalty (@{$user->standing_penalties()}) {
            next unless($penalty->standing_penalty->block_list());
            my @block_list = split(/\|/, $penalty->standing_penalty->block_list());
            my $ou = $U->simplereq(
                'open-ils.pcrud',
                'open-ils.pcrud.retrieve.aou',
                $self->{session}->{authtoken},
                $penalty->org_unit()
            );

            # Block checkout.
            if (!$have_circ && grep {$_ eq 'CIRC'} @block_list) {
                my $bot = NCIP::User::BlockOrTrap->new();
                $bot->AgencyId($ou->shortname());
                $bot->BlockOrTrapType('Block Checkout');
                push @$blocks, $bot;
                $have_circ = 1;
            }

            # Block holds.
            if (!$have_hold && grep {$_ eq 'HOLD' || $_ eq 'FULFILL'} @block_list) {
                my $bot = NCIP::User::BlockOrTrap->new();
                $bot->AgencyId($ou->shortname());
                $bot->BlockOrTrapType('Block Holds');
                push @$blocks, $bot;
                $have_hold = 1;
            }

            # Block renewals.
            if (!$have_renew && grep {$_ eq 'RENEW'} @block_list) {
                my $bot = NCIP::User::BlockOrTrap->new();
                $bot->AgencyId($ou->shortname());
                $bot->BlockOrTrapType('Block Renewals');
                push @$blocks, $bot;
                $have_renew = 1;
            }

            # Stop after we report one of each, even if more
            # blocks remain.
            last if ($have_circ && $have_renew && $have_hold);
        }

        $optionalfields->BlockOrTrap($blocks);
    }

    return $optionalfields;
}

=head2 handle_item_elements

=cut

sub handle_item_elements {
    my $self = shift;
    my $copy = shift;
    my $elements = shift;
    my $optionalfields = NCIP::Item::OptionalFields->new();

    my $details; # In case we need for more than one.

    if (grep {$_ eq 'Bibliographic Description'} @$elements) {
        my $description;
        # Check for a precat copy, 'cause it is simple.
        if ($copy->dummy_title()) {
            $description = NCIP::Item::BibliographicDescription->new();
            $description->Title($copy->dummy_title());
            $description->Author($copy->dummy_author());
            if ($copy->dummy_isbn()) {
                $description->BibliographicItemId(
                    NCIP::Item::BibliographicItemId->new(
                        {
                            BibliographicItemIdentifier => $copy->dummy_isbn(),
                            BibliographicItemIdentifierCode => 'ISBN'
                        }
                    )
                );
            }
        } else {
            $details = $self->retrieve_copy_details_by_barcode($copy->barcode()) unless($details);
            $description = NCIP::Item::BibliographicDescription->new();
            $description->Title($details->{mvr}->title());
            $description->Author($details->{mvr}->author());
            $description->BibliographicRecordId(
                NCIP::Item::BibliographicRecordId->new(
                    {
                        BibliographicRecordIdentifier => $details->{mvr}->doc_id(),
                        BibliographicRecordIdentifierCode => 'SYSNUMBER'
                    }
                )
            );
            if ($details->{mvr}->publisher()) {
                $description->Publisher($details->{mvr}->publisher());
            }
            if ($details->{mvr}->pubdate()) {
                $description->PublicationDate($details->{mvr}->pubdate());
            }
            if ($details->{mvr}->edition()) {
                $description->Edition($details->{mvr}->edition());
            }
        }
        $optionalfields->BibliographicDescription($description) if ($description);
    }

    if (grep {$_ eq 'Item Description'} @$elements) {
        $details = $self->retrieve_copy_details_by_barcode($copy->barcode()) unless($details);
        # Call Number is the only field we currently return. We also
        # do not attempt to retun a prefix and suffix. Someone else
        # can deal with that if they want it.
        if ($details->{volume}) {
            $optionalfields->ItemDescription(
                NCIP::Item::Description->new(
                    {CallNumber => $details->{volume}->label()}
                )
            );
        }
    }

    if (grep {$_ eq 'Circulation Status'} @$elements) {
        my $status = $copy->status();
        $status = $self->retrieve_copy_status($status) unless (ref($status));
        $optionalfields->CirculationStatus($status->name()) if ($status);
    }

    if (grep {$_ eq 'Date Due'} @$elements) {
        $details = $self->retrieve_copy_details_by_barcode($copy->barcode()) unless($details);
        if ($details->{circ}) {
            if (!$details->{circ}->checkin_time()) {
                $optionalfields->DateDue(_fix_date($details->{circ}->due_date()));
            }
        }
    }

    if (grep {$_ eq 'Item Use Restriction Type'} @$elements) {
        $optionalfields->ItemUseRestrictionType('None');
    }

    if (grep {$_ eq 'Physical Condition'} @$elements) {
        $optionalfields->PhysicalCondition(
            NCIP::Item::PhysicalCondition->new(
                {PhysicalConditionType => 'Unknown'}
            )
        );
    }

    return $optionalfields;
}

=head2 login

    $ils->login();

Login to Evergreen via OpenSRF. It uses internal state from the
configuration file to login.

=cut

# Login via OpenSRF to Evergreen.
sub login {
    my $self = shift;

    # Get the authentication seed.
    my $seed = $U->simplereq(
        'open-ils.auth',
        'open-ils.auth.authenticate.init',
        $self->{config}->{credentials}->{username}
    );

    # Actually login.
    if ($seed) {
        my $response = $U->simplereq(
            'open-ils.auth',
            'open-ils.auth.authenticate.complete',
            {
                username => $self->{config}->{credentials}->{username},
                password => md5_hex(
                    $seed . md5_hex($self->{config}->{credentials}->{password})
                ),
                type => 'staff',
                workstation => $self->{config}->{credentials}->{workstation}
            }
        );
        if ($response) {
            $self->{session}->{authtoken} = $response->{payload}->{authtoken};
            $self->{session}->{authtime} = $response->{payload}->{authtime};

            # Set/reset the work_ou and user data in case something changed.

            # Retrieve the work_ou as an object.
            $self->{session}->{work_ou} = $U->simplereq(
                'open-ils.pcrud',
                'open-ils.pcrud.search.aou',
                $self->{session}->{authtoken},
                {shortname => $self->{config}->{credentials}->{work_ou}}
            );

            # We need the user information in order to do some things.
            $self->{session}->{user} = $U->check_user_session($self->{session}->{authtoken});

        }
    }
}

=head2 checkauth

    $valid = $ils->checkauth();

Returns 1 if the object a 'valid' authtoken, 0 if not.

=cut

sub checkauth {
    my $self = shift;

    # We use AppUtils to do the heavy lifting.
    if (defined($self->{session})) {
        if ($U->check_user_session($self->{session}->{authtoken})) {
            return 1;
        } else {
            return 0;
        }
    }

    # If we reach here, we don't have a session, so we are definitely
    # not logged in.
    return 0;
}

=head2 retrieve_user_by_barcode

    $user = $ils->retrieve_user_by_barcode($user_barcode, $user_idfield);

Do a fleshed retrieve of a patron by barcode. Return the patron if
found and valid. Return a NCIP::Problem of 'Unknown User' otherwise.

The id field argument is used for the ProblemElement field in the
NCIP::Problem object.

An invalid patron is one where the barcode is not found in the
database, the patron is deleted, or the barcode used to retrieve the
patron is not active. The problem element is also returned if an error
occurs during the retrieval.

=cut

sub retrieve_user_by_barcode {
    my ($self, $barcode, $idfield) = @_;
    my $result = $U->simplereq(
        'open-ils.actor',
        'open-ils.actor.user.fleshed.retrieve_by_barcode',
        $self->{session}->{authtoken},
        $barcode,
        1
    );

    # Check for a failure, or a deleted, inactive, or expired user,
    # and if so, return empty userdata.
    if (!$result || $U->event_code($result) || $U->is_true($result->deleted())
            || !grep {$_->barcode() eq $barcode && $U->is_true($_->active())} @{$result->cards()}) {

        my $problem = NCIP::Problem->new();
        $problem->ProblemType('Unknown User');
        $problem->ProblemDetail("User with barcode $barcode unknown");
        $problem->ProblemElement($idfield);
        $problem->ProblemValue($barcode);
        $result = $problem;
    }

    return $result;
}

=head2 retrieve_user_by_id

    $user = $ils->retrieve_user_by_id($id);

Similar to C<retrieve_user_by_barcode> but takes the user's database
id rather than barcode. This is useful when you have a circulation or
hold and need to get information about the user's involved in the hold
or circulaiton.

It returns a fleshed user on success or undef on failure.

=cut

sub retrieve_user_by_id {
    my ($self, $id) = @_;

    # Do a fleshed retrieve of the patron, and flesh the fields that
    # we would normally use.
    my $result = $U->simplereq(
        'open-ils.actor',
        'open-ils.actor.user.fleshed.retrieve',
        $self->{session}->{authtoken},
        $id,
        [ 'card', 'cards', 'standing_penalties', 'addresses', 'home_ou' ]
    );
    # Check for an error.
    undef($result) if ($result && $U->event_code($result));

    return $result;
}

=head2 check_user_for_problems

    $problem = $ils>check_user_for_problems($user, 'HOLD, 'CIRC', 'RENEW');

This function checks if a user has a blocked profile or any from a
list of provided blocks. If it does, then a NCIP::Problem object is
returned, otherwise an undefined value is returned.

The list of blocks appears as additional arguments after the user. You
can provide any value(s) that might appear in a standing penalty block
lit in Evergreen. The example above checks for HOLD, CIRC, and
RENEW. Any number of such values can be provided. If none are
provided, the function only checks if the patron's profiles appears in
the object's blocked profiles list.

It stops on the first matching block, if any.

=cut

sub check_user_for_problems {
    my $self = shift;
    my $user = shift;
    my @blocks = @_;

    # Fill this in if we have a problem, otherwise just return it.
    my $problem;

    # First, check the user's profile.
    if (grep {$_->id() == $user->profile()} @{$self->{blocked_profiles}}) {
        $problem = NCIP::Problem->new(
            {
                ProblemType => 'User Blocked',
                ProblemDetail => 'User blocked from inter-library loan',
                ProblemElement => 'NULL',
                ProblemValue => 'NULL'
            }
        );
    }

    # Next, check if the patron has one of the indicated blocks.
    unless ($problem) {
        foreach my $penalty (@{$user->standing_penalties()}) {
            if ($penalty->standing_penalty->block_list()) {
                my @pblocks = split(/\|/, $penalty->standing_penalty->block_list());
                foreach my $block (@blocks) {
                    if (grep {$_ =~ /$block/} @pblocks) {
                        $problem = NCIP::Problem->new(
                            {
                                ProblemType => 'User Blocked',
                                ProblemDetail => 'User blocked from ' .
                                    ($block eq 'HOLD') ? 'holds' : (($block eq 'RENEW') ? 'renewals' :
                                                                        (($block eq 'CIRC') ? 'checkout' : lc($block))),
                                ProblemElement => 'NULL',
                                ProblemValue => 'NULL'
                            }
                        );
                        last;
                    }
                }
                last if ($problem);
            }
        }
    }

    return $problem;
}

=head2 check_circ_details

    $problem = $ils->check_circ_details($circ, $copy, $user);

Checks if we can checkin or renew a circulation. That is, the
circulation is still open (i.e. the copy is still checked out), if we
either own the copy or are the circulation location, and if the
circulation is for the optional $user argument. $circ and $copy are
required. $user is optional.

Returns a problem if any of the above conditions fail. Returns undef
if they pass and we can proceed with the checkin or renewal.

If the failure occurred on the copy-related checks, then the
ProblemElement field will be undefined and needs to be filled in with
the item id field name. If the check for the copy being checked out to
the provided user fails, then both ProblemElement and ProblemValue
fields will be empty and need to be filled in by the caller.

=cut

sub check_circ_details {
    my ($self, $circ, $copy, $user) = @_;

    # Shortcut for the next check.
    my $ou_id = $self->{session}->{work_ou}->id();

    if (!$circ || $circ->checkin_time() || ($circ->circ_lib() != $ou_id && $copy->circ_lib() != $ou_id)) {
        # Item isn't checked out.
        return NCIP::Problem->new(
            {
                ProblemType => 'Item Not Checked Out',
                ProblemDetail => 'Item with barcode ' . $copy->barcode() . ' is not checked out.',
                ProblemValue => $copy->barcode()
            }
        );
    } else {
        # Get data on the patron who has it checked out.
        my $circ_user = $self->retrieve_user_by_id($circ->usr());
        if ($user && $circ_user && $user->id() != $circ_user->id()) {
            # The ProblemElement and ProblemValue field need to be
            # filled in by the caller.
            return NCIP::Problem->new(
                {
                    ProblemType => 'Item Not Checked Out To This User',
                    ProblemDetail => 'Item with barcode ' . $copy->barcode() . ' is not checked out to this user.',
                }
            );
        }
    }
    # If we get here, we're good to go.
    return undef;
}

=head2 retrieve_copy_details_by_barcode

    $copy = $ils->retrieve_copy_details_by_barcode($copy_barcode);

Look up and retrieve some copy details by the copy barcode. This
method returns either a hashref with the copy details or undefined if
no copy exists with that barcode or if some error occurs.

The hashref has the fields copy, hold, transit, circ, volume, and mvr.

This method differs from C<retrieve_user_by_barcode> in that a copy
cannot be invalid if it exists and it is not always an error if no
copy exists. In some cases, when handling AcceptItem, we might prefer
there to be no copy.

=cut

sub retrieve_copy_details_by_barcode {
    my $self = shift;
    my $barcode = shift;

    my $copy = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.copy_details.retrieve.barcode',
        $self->{session}->{authtoken},
        $barcode
    );

    # If $copy is an event, return undefined.
    if ($copy && $U->event_code($copy)) {
        undef($copy);
    }

    return $copy;
}

=head2 retrieve_copy_details_by_id

    $copy = $ils->retrieve_copy_details_by_id($copy_id);

Retrieve copy_details by copy id. Same as the above, but with a copy
id instead of barcode.

=cut

sub retrieve_copy_details_by_id {
    my $self = shift;
    my $copy_id = shift;

    my $copy = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.copy_details.retrieve',
        $self->{session}->{authtoken},
        $copy_id
    );

    # If $copy is an event, return undefined.
    if ($copy && $U->event_code($copy)) {
        undef($copy);
    }

    return $copy;
}

=head2 retrieve_copy_status

    $status = $ils->retrieve_copy_status($id);

Retrive a copy status object by database ID.

=cut

sub retrieve_copy_status {
    my $self = shift;
    my $id = shift;

    my $status = $U->simplereq(
        'open-ils.pcrud',
        'open-ils.pcrud.retrieve.ccs',
        $self->{session}->{authtoken},
        $id
    );

    return $status;
}

=head2 retrieve_org_unit_by_shortname

    $org_unit = $ils->retrieve_org_unit_by_shortname($shortname);

Retrieves an org. unit from the database by shortname, and fleshes the
ou_type field. Returns the org. unit as a Fieldmapper object or
undefined.

=cut

sub retrieve_org_unit_by_shortname {
    my $self = shift;
    my $shortname = shift;

    my $aou = $U->simplereq(
        'open-ils.actor',
        'open-ils.actor.org_unit.retrieve_by_shortname',
        $shortname
    );

    # We want to retrieve the type and manually "flesh" the object.
    if ($aou) {
        my $type = $U->simplereq(
            'open-ils.pcrud',
            'open-ils.pcrud.retrieve.aout',
            $self->{session}->{authtoken},
            $aou->ou_type()
        );
        $aou->ou_type($type) if ($type);
    }

    return $aou;
}

=head2 retrieve_copy_location

    $location = $ils->retrieve_copy_location($location_id);

Retrieve a copy location based on id.

=cut

sub retrieve_copy_location {
    my $self = shift;
    my $id = shift;

    my $location = $U->simplereq(
        'open-ils.pcrud',
        'open-ils.pcrud.retrieve.acpl',
        $self->{session}->{authtoken},
        $id
    );

    return $location;
}

=head2 retrieve_biblio_record_entry

    $bre = $ils->retrieve_biblio_record_entry($bre_id);

Given a biblio.record_entry.id, this method retrieves a bre object.

=cut

sub retrieve_biblio_record_entry {
    my $self = shift;
    my $id = shift;

    my $bre = $U->simplereq(
        'open-ils.pcrud',
        'open-ils.pcrud.retrieve.bre',
        $self->{session}->{authtoken},
        $id
    );

    return $bre;
}

=head2 create_precat_copy

    $item_info->{
        barcode => '312340123456789',
        author => 'Public, John Q.',
        title => 'Magnum Opus',
        call_number => '005.82',
        publisher => 'Brick House',
        publication_date => '2014'
    };

    $item = $ils->create_precat_copy($item_info);


Create a "precat" copy to use for the incoming item using a hashref of
item information. At a minimum, the barcode, author and title fields
need to be filled in. The other fields are ignored if provided.

This method is called by the AcceptItem handler if the C<use_precats>
configuration option is turned on.

=cut

sub create_precat_copy {
    my $self = shift;
    my $item_info = shift;

    my $item = Fieldmapper::asset::copy->new();
    $item->barcode($item_info->{barcode});
    $item->call_number(OILS_PRECAT_CALL_NUMBER);
    $item->dummy_title($item_info->{title});
    $item->dummy_author($item_info->{author});
    $item->circ_lib($self->{session}->{work_ou}->id());
    $item->circulate('t');
    $item->holdable('t');
    $item->opac_visible('f');
    $item->deleted('f');
    $item->fine_level(OILS_PRECAT_COPY_FINE_LEVEL);
    $item->loan_duration(OILS_PRECAT_COPY_LOAN_DURATION);
    $item->location(1);
    $item->status(0);
    $item->editor($self->{session}->{user}->id());
    $item->creator($self->{session}->{user}->id());
    $item->isnew(1);

    # Actually create it:
    my $xact;
    my $ses = OpenSRF::AppSession->create('open-ils.pcrud');
    $ses->connect();
    eval {
        $xact = $ses->request(
            'open-ils.pcrud.transaction.begin',
            $self->{session}->{authtoken}
        )->gather(1);
        $item = $ses->request(
            'open-ils.pcrud.create.acp',
            $self->{session}->{authtoken},
            $item
        )->gather(1);
        $xact = $ses->request(
            'open-ils.pcrud.transaction.commit',
            $self->{session}->{authtoken}
        )->gather(1);
    };
    if ($@) {
        undef($item);
        if ($xact) {
            eval {
                $ses->request(
                    'open-ils.pcrud.transaction.rollback',
                    $self->{session}->{authtoken}
                )->gather(1);
            };
        }
    }
    $ses->disconnect();

    return $item;
}

=head2 create_fuller_copy

    $item_info->{
        barcode => '31234003456789',
        author => 'Public, John Q.',
        title => 'Magnum Opus',
        call_number => '005.82',
        publisher => 'Brick House',
        publication_date => '2014'
    };

    $item = $ils->create_fuller_copy($item_info);

Creates a skeletal bibliographic record, call number, and copy for the
incoming item using a hashref with item information in it. At a
minimum, the barcode, author, title, and call_number fields must be
filled in.

This method is used by the AcceptItem handler if the C<use_precats>
configuration option is NOT set.

=cut

sub create_fuller_copy {
    my $self = shift;
    my $item_info = shift;

    my $item;

    # We do everything in one transaction, because it should be atomic.
    my $ses = OpenSRF::AppSession->create('open-ils.pcrud');
    $ses->connect();
    my $xact;
    eval {
        $xact = $ses->request(
            'open-ils.pcrud.transaction.begin',
            $self->{session}->{authtoken}
        )->gather(1);
    };
    if ($@) {
        undef($xact);
    }

    # The rest depends on there being a transaction.
    if ($xact) {

        # Create the MARC record.
        my $record = MARC::Record->new();
        $record->encoding('UTF-8');
        $record->leader('00881nam a2200193   4500');
        my $datespec = strftime("%Y%m%d%H%M%S.0", localtime);
        my @fields = ();
        push(@fields, MARC::Field->new('005', $datespec));
        push(@fields, MARC::Field->new('082', '0', '4', 'a' => $item_info->{call_number}));
        push(@fields, MARC::Field->new('245', '0', '0', 'a' => $item_info->{title}));
        # Publisher is a little trickier:
        if ($item_info->{publisher}) {
            my $pub = MARC::Field->new('260', ' ', ' ', 'a' => '[S.l.]', 'b' => $item_info->{publisher});
            $pub->add_subfields('c' => $item_info->{publication_date}) if ($item_info->{publication_date});
            push(@fields, $pub);
        }
        # We have no idea if the author is personal corporate or something else, so we use a 720.
        push(@fields, MARC::Field->new('720', ' ', ' ', 'a' => $item_info->{author}, '4' => 'aut'));
        $record->append_fields(@fields);
        my $marc = clean_marc($record);

        # Create the bib object.
        my $bib = Fieldmapper::biblio::record_entry->new();
        $bib->creator($self->{session}->{user}->id());
        $bib->editor($self->{session}->{user}->id());
        $bib->source($self->{bib_source}->id());
        $bib->active('t');
        $bib->deleted('f');
        $bib->marc($marc);
        $bib->isnew(1);

        eval {
            $bib = $ses->request(
                'open-ils.pcrud.create.bre',
                $self->{session}->{authtoken},
                $bib
            )->gather(1);
        };
        if ($@) {
            undef($bib);
            eval {
                $ses->request(
                    'open-ils.pcrud.transaction.rollback',
                    $self->{session}->{authtoken}
                )->gather(1);
            };
        }

        # Create the call number
        my $acn;
        if ($bib) {
            $acn = Fieldmapper::asset::call_number->new();
            $acn->creator($self->{session}->{user}->id());
            $acn->editor($self->{session}->{user}->id());
            $acn->label($item_info->{call_number});
            $acn->record($bib->id());
            $acn->owning_lib($self->{session}->{work_ou}->id());
            $acn->deleted('f');
            $acn->isnew(1);

            eval {
                $acn = $ses->request(
                    'open-ils.pcrud.create.acn',
                    $self->{session}->{authtoken},
                    $acn
                )->gather(1);
            };
            if ($@) {
                undef($acn);
                eval {
                    $ses->request(
                        'open-ils.pcrud.transaction.rollback',
                        $self->{session}->{authtoken}
                    )->gather(1);
                };
            }
        }

        # create the copy
        if ($acn) {
            $item = Fieldmapper::asset::copy->new();
            $item->barcode($item_info->{barcode});
            $item->call_number($acn->id());
            $item->circ_lib($self->{session}->{work_ou}->id);
            $item->circulate('t');
            if ($self->{config}->{items}->{use_force_holds}) {
                $item->holdable('f');
            } else {
                $item->holdable('t');
            }
            $item->opac_visible('f');
            $item->deleted('f');
            $item->fine_level(OILS_PRECAT_COPY_FINE_LEVEL);
            $item->loan_duration(OILS_PRECAT_COPY_LOAN_DURATION);
            $item->location(1);
            $item->status(0);
            $item->editor($self->{session}->{user}->id);
            $item->creator($self->{session}->{user}->id);
            $item->isnew(1);

            eval {
                $item = $ses->request(
                    'open-ils.pcrud.create.acp',
                    $self->{session}->{authtoken},
                    $item
                )->gather(1);

                # Cross our fingers and commit the work.
                $xact = $ses->request(
                    'open-ils.pcrud.transaction.commit',
                    $self->{session}->{authtoken}
                )->gather(1);
            };
            if ($@) {
                undef($item);
                eval {
                    $ses->request(
                        'open-ils.pcrud.transaction.rollback',
                        $self->{session}->{authtoken}
                    )->gather(1) if ($xact);
                };
            }
        }
    }

    # We need to disconnect our session.
    $ses->disconnect();

    # Now, we handle our asset stat_cat entries.
    if ($item) {
        # It would be nice to do these in the above transaction, but
        # pcrud does not support the ascecm object, yet.
        foreach my $entry (@{$self->{stat_cat_entries}}) {
            my $map = Fieldmapper::asset::stat_cat_entry_copy_map->new();
            $map->isnew(1);
            $map->stat_cat($entry->stat_cat());
            $map->stat_cat_entry($entry->id());
            $map->owning_copy($item->id());
            # We don't really worry if it succeeds or not.
            $U->simplereq(
                'open-ils.circ',
                'open-ils.circ.stat_cat.asset.copy_map.create',
                $self->{session}->{authtoken},
                $map
            );
        }
    }

    return $item;
}

=head2 place_hold

    $hold = $ils->place_hold($item, $user, $location, $expiration, $org_unit);

This function places a hold on $item for $user for pickup at
$location. If location is not provided or undefined, the user's home
library is used as a fallback.

The $expiration argument is optional and must be a properly formatted
ISO date time. It will be used as the hold expire time, if
provided. Otherwise the system default time will be used.

The $org_unit parameter is only consulted in the event of $item being
a biblio::record_entry object.  In which case, it is expected to be
undefined or an actor::org_unit object.  If it is present, then its id
and ou_type depth (if the ou_type field is fleshed) will be used to
control the selection ou and selection depth for the hold.  This
essentially limits the hold to being filled by copies belonging to the
specified org_unit or its children.

$item can be a copy (asset::copy), volume (asset::call_number), or bib
(biblio::record_entry). The appropriate hold type will be placed
depending on the object.

On success, the method returns the object representing the hold. On
failure, a NCIP::Problem object, describing the failure, is returned.

=cut

sub place_hold {
    my $self = shift;
    my $item = shift;
    my $user = shift;
    my $location = shift;
    my $expiration = shift;
    my $org_unit = shift;

    # If $location is undefined, use the user's home_ou, which should
    # have been fleshed when the user was retrieved.
    $location = $user->home_ou() unless ($location);

    # $hold is the hold. $params is for the is_possible check.
    my ($hold, $params);

    # Prep the hold with fields common to all hold types:
    $hold = Fieldmapper::action::hold_request->new();
    $hold->isnew(1); # Just to make sure.
    $hold->target($item->id());
    $hold->usr($user->id());
    $hold->pickup_lib($location->id());
    $hold->expire_time(cleanse_ISO8601($expiration)) if ($expiration);
    if (!$user->email()) {
        $hold->email_notify('f');
        $hold->phone_notify($user->day_phone()) if ($user->day_phone());
    } else {
        $hold->email_notify('t');
    }

    # Ditto the params:
    $params = { pickup_lib => $location->id(), patronid => $user->id() };

    if (ref($item) eq 'Fieldmapper::asset::copy') {
        my $type = ($self->{config}->{items}->{use_force_holds}) ? 'F' : 'C';
        $hold->hold_type($type);
        $hold->current_copy($item->id());
        $params->{hold_type} = $type;
        $params->{copy_id} = $item->id();
    } elsif (ref($item) eq 'Fieldmapper::asset::call_number') {
        $hold->hold_type('V');
        $params->{hold_type} = 'V';
        $params->{volume_id} = $item->id();
    } elsif (ref($item) eq 'Fieldmapper::biblio::record_entry') {
        $hold->hold_type('T');
        $params->{hold_type} = 'T';
        $params->{titleid} = $item->id();
        if ($org_unit && ref($org_unit) eq 'Fieldmapper::actor::org_unit') {
            $hold->selection_ou($org_unit->id());
            $hold->selection_depth($org_unit->ou_type->depth()) if (ref($org_unit->ou_type()));
        }
    }

    # Check for a duplicate hold:
    my $duplicate = $U->simplereq(
        'open-ils.pcrud',
        'open-ils.pcrud.search.ahr',
        $self->{session}->{authtoken},
        {
            hold_type => $hold->hold_type(),
            target => $hold->target(),
            usr => $hold->usr(),
            expire_time => {'>' => 'now'},
            cancel_time => undef,
            fulfillment_time => undef
        }
    );
    if ($duplicate) {
        return NCIP::Problem->new(
            {
                ProblemType => 'Duplicate Request',
                ProblemDetail => 'A request for this item already exists for this patron.',
                ProblemElement => 'NULL',
                ProblemValue => 'NULL'
            }
        );
    }

    # Check if the hold is possible:
    my $r = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.title_hold.is_possible',
        $self->{session}->{authtoken},
        $params
    );

    if ($r->{success}) {
        $hold = $U->simplereq(
            'open-ils.circ',
            'open-ils.circ.holds.create.override',
            $self->{session}->{authtoken},
            $hold
        );
        if (ref($hold)) {
            $hold = $hold->[0] if (ref($hold) eq 'ARRAY');
            $hold = _problem_from_event('User Ineligible To Request This Item', $hold);
        } else {
            # open-ils.circ.holds.create.override returns the id on
            # success, so we retrieve the full hold object from the
            # database to return it.
            $hold = $U->simplereq(
                'open-ils.pcrud',
                'open-ils.pcrud.retrieve.ahr',
                $self->{session}->{authtoken},
                $hold
            );
        }
    } elsif ($r->{last_event}) {
        $hold = _problem_from_event('User Ineligible To Request This Item', $r->{last_event});
    } elsif ($r->{textcode}) {
        $hold = _problem_from_event('User Ineligible To Request This Item', $r);
    } else {
        $hold = _problem_from_event('User Ineligible To Request This Item');
    }

    return $hold;
}

=head2 cancel_hold

    $ils->cancel_hold($hold);

This method cancels the hold argument. It makes no checks on the hold,
so if there are certain conditions that need to be fulfilled before
the hold is canceled, then you must check them before calling this
method.

It returns undef on success or failure. If it fails, you've usually
got bigger problems.

=cut

sub cancel_hold {
    my $self = shift;
    my $hold = shift;

    my $r = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.hold.cancel',
        $self->{session}->{authtoken},
        $hold->id(),
        '5',
        'Canceled via NCIPServer'
    );

    return undef;
}

=head2 delete_copy

    $ils->delete_copy($copy);

Deletes the copy, and if it is owned by our work_ou and not a precat,
we also delete the volume and bib on which the copy depends.

=cut

sub delete_copy {
    my $self = shift;
    my $copy = shift;

    # Shortcut for ownership checks below.
    my $ou_id = $self->{session}->{work_ou}->id();

    # First, make sure the copy is not already deleted and we own it.
    return undef if ($U->is_true($copy->deleted()) || $copy->circ_lib() != $ou_id);

    # Indicate we want to delete the copy.
    $copy->isdeleted(1);

    # Delete the copy using a backend call that will delete the copy,
    # the call number, and bib when appropriate.
    my $result = $U->simplereq(
        'open-ils.cat',
        'open-ils.cat.asset.copy.fleshed.batch.update.override',
        $self->{session}->{authtoken},
        [$copy]
    );

    # We are currently not checking for succes or failure of the
    # above. At some point, someone may want to.

    return undef;
}

=head2 copy_can_circulate

    $can_circulate = $ils->copy_can_circulate($copy);

Check if the copy's location and the copy itself allow
circulation. Return true if they do, and false if they do not.

=cut

sub copy_can_circulate {
    my $self = shift;
    my $copy = shift;

    my $location = $copy->location();
    unless (ref($location)) {
        $location = $self->retrieve_copy_location($location);
    }

    return ($U->is_true($copy->circulate()) && $U->is_true($location->circulate()));
}

=head1 OVERRIDDEN PARENT METHODS

=head2 find_user_barcode

We dangerously override our parent's C<find_user_barcode> to return
either the $barcode or a Problem object. In list context the barcode
or problem will be the first argument and the id field, if any, will
be the second. We also add a second, optional, argument to indicate a
default value for the id field in the event of a failure to find
anything at all. (Perl lets us get away with this.)

=cut

sub find_user_barcode {
    my $self = shift;
    my $request = shift;
    my $default = shift;

    unless ($default) {
        my $message = $self->parse_request_type($request);
        if ($message eq 'LookupUser') {
            $default = 'AuthenticationInputData';
        } else {
            $default = 'UserIdentifierValue';
        }
    }

    my ($value, $idfield) = $self->SUPER::find_user_barcode($request);

    unless ($value) {
        $idfield = $default unless ($idfield);
        $value = NCIP::Problem->new();
        $value->ProblemType('Needed Data Missing');
        $value->ProblemDetail('Cannot find user barcode in message.');
        $value->ProblemElement($idfield);
        $value->ProblemValue('NULL');
    }

    return (wantarray) ? ($value, $idfield) : $value;
}

=head2 find_item_barcode

We do pretty much the same thing as with C<find_user_barcode> for
C<find_item_barcode>.

=cut

sub find_item_barcode {
    my $self = shift;
    my $request = shift;
    my $default = shift || 'ItemIdentifierValue';

    my ($value, $idfield) = $self->SUPER::find_item_barcode($request);

    unless ($value) {
        $idfield = $default unless ($idfield);
        $value = NCIP::Problem->new();
        $value->ProblemType('Needed Data Missing');
        $value->ProblemDetail('Cannot find item barcode in message.');
        $value->ProblemElement($idfield);
        $value->ProblemValue('NULL');
    }

    return (wantarray) ? ($value, $idfield) : $value;
}

=head2 find_target_details_by_bre

    $copy_details = $ils->find_target_details_by_bre($bre, $selection_ou);

Returns copy details hashref for the "first" holdable copy found on a
biblio.record_entry at an optionally given selection organization.  If
no suitable copy is found, this method returns undef.

=cut

sub find_target_details_by_bre {
    my $self = shift;
    my $bre = shift;
    my $selection_ou = shift;

    # The copy details that we find:
    my $details;

    # We're going to search for non-deleted call numbers and flesh
    # copies with copy location and copy status.
    my $acns = $self->_call_number_search($bre->id(), $selection_ou, 1);
    if ($acns && @$acns) {
        # Now, we get available copies, sorted by status id.  We
        # only need one, so we take the first that comes out.
        my @copies;
        foreach (@$acns) {
            push(@copies, @{$_->copies()});
        }
        my ($copy) = sort {$a->status->id() <=> $b->status->id()}
            grep { $_->deleted() eq 'f' && $_->holdable() eq 't' && $_->circulate() eq 't' &&
                       $_->location->holdable() eq 't' && $_->location->circulate() eq 't' &&
                           $_->status->holdable() eq 't' && $_->status->copy_active() eq 't' }
                @copies;
        if ($copy) {
            $details = $self->retrieve_copy_details_by_id($copy->id());
        }
    }

    return $details;
}

=head2 find_location_failover

    $location = $ils->find_location_failover($location, $request, $message);

Attempts to retrieve an org_unit by shortname from the passed in
$location.  If that fails, $request and $message are used to lookup
the ToAgencyId/AgencyId field and that is used.  Returns an org_unit
as retrieved by retrieve_org_unit_by_shortname if successful and undef
on failure.

=cut

sub find_location_failover {
    my ($self, $location, $request, $message) = @_;
    if ($request && !$message) {
        $message = $self->parse_request_type($request);
    }
    my $org_unit;
    if ($location) {
        # Because Auto-Graphics. (This should be configured somehow.)
        $location =~ s/^[^-]+-//;
        $org_unit = $self->retrieve_org_unit_by_shortname($location);
    }
    if ($request && $message && !$org_unit) {
        $location = $request->{$message}->{InitiationHeader}->{ToAgencyId}->{AgencyId};
        if ($location) {
            # Because Auto-Graphics. (This should be configured somehow.)
            $location =~ s/^[^-]+-//;
            $org_unit = $self->retrieve_org_unit_by_shortname($location);
        }
    }

    return $org_unit;
}

# private subroutines not meant to be used directly by subclasses.
# Most have to do with setup and/or state checking of implementation
# components.

# Find, load, and parse our configuration file:
sub _configure {
    my $self = shift;

    # Find the configuration file via variables:
    my $file = OILS_NCIP_CONFIG_DEFAULT;
    $file = $ENV{OILS_NCIP_CONFIG} if ($ENV{OILS_NCIP_CONFIG});

    $self->{config} = XMLin($file, NormaliseSpace => 2,
                            ForceArray => ['block_profile', 'stat_cat_entry']);
}

# Bootstrap OpenSRF::System and load the IDL.
sub _bootstrap {
    my $self = shift;

    my $bootstrap_config = $self->{config}->{bootstrap};
    OpenSRF::System->bootstrap_client(config_file => $bootstrap_config);

    my $idl = OpenSRF::Utils::SettingsClient->new->config_value("IDL");
    Fieldmapper->import(IDL => $idl);
}

# Login and then initialize some object data based on the
# configuration.
sub _init {
    my $self = shift;

    # Login to Evergreen.
    $self->login();

    # Load the barred groups as pgt objects into a blocked_profiles
    # list.
    $self->{blocked_profiles} = [];
    if (ref($self->{config}->{patrons}) eq 'HASH') {
        foreach (@{$self->{config}->{patrons}->{block_profile}}) {
            my $pgt;
            if (ref $_) {
                $pgt = $U->simplereq(
                    'open-ils.pcrud',
                    'open-ils.pcrud.retrieve.pgt',
                    $self->{session}->{authtoken},
                    $_->{grp}
                );
            } else {
                $pgt = $U->simplereq(
                    'open-ils.pcrud',
                    'open-ils.pcrud.search.pgt',
                    $self->{session}->{authtoken},
                    {
                        name => $_}
                );
            }
            push(@{$self->{blocked_profiles}}, $pgt) if ($pgt);
        }
    }

    # Load the bib source if we're not using precats.
    unless ($self->{config}->{items}->{use_precats}) {
        # Retrieve the default
        $self->{bib_source} = $U->simplereq(
            'open-ils.pcrud',
            'open-ils.pcrud.retrieve.cbs',
            $self->{session}->{authtoken},
            BIB_SOURCE_DEFAULT);
        my $data = $self->{config}->{items}->{bib_source};
        if ($data) {
            $data = $data->[0] if (ref($data) eq 'ARRAY');
            my $result;
            if (ref $data) {
                $result = $U->simplereq(
                    'open-ils.pcrud',
                    'open-ils.pcrud.retrieve.cbs',
                    $self->{session}->{authtoken},
                    $data->{cbs}
                );
            } else {
                $result = $U->simplereq(
                    'open-ils.pcrud',
                    'open-ils.pcrud.search.cbs',
                    $self->{session}->{authtoken},
                    {source => $data}
                );
            }
            $self->{bib_source} = $result if ($result);
        }
    }

    # Load the required asset.stat_cat_entries:
    $self->{stat_cat_entries} = [];
    # First, make a regex for our ou and ancestors:
    my $ancestors = join("|", @{$U->get_org_ancestors($self->{session}->{work_ou}->id())});
    my $re = qr/(?:$ancestors)/;
    # Get the uniq stat_cat ids from the configuration:
    my @cats = uniq map {$_->{stat_cat}} @{$self->{config}->{items}->{stat_cat_entry}};
    # Retrieve all of the fleshed stat_cats and entries for the above.
    my $stat_cats = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.stat_cat.asset.retrieve.batch',
        $self->{session}->{authtoken},
        @cats
    );
    foreach my $entry (@{$self->{config}->{items}->{stat_cat_entry}}) {
        # Must have the stat_cat attr and the name, so we must have a
        # reference.
        next unless(ref $entry);
        my ($stat) = grep {$_->id() == $entry->{stat_cat}} @$stat_cats;
        push(@{$self->{stat_cat_entries}}, grep {$_->owner() =~ $re && $_->value() eq $entry->{content}} @{$stat->entries()});
    }
}

# Search asset.call_number by a bre.id and location object.
sub _call_number_search {
    my $self = shift;
    my $bibid = shift;
    my $location = shift;
    my $flesh = shift;

    my $search = {record => $bibid, deleted => 'f'};
    if ($location) {
        $search->{owning_lib} = $location->id();
    }

    # If flesh is passed a true value, we flesh copies, copy status,
    # and copy location for the call numbers.
    if ($flesh) {
        $flesh = {
            flesh => 2,
            flesh_fields => {
                acn => ['copies'],
                acp => ['status', 'location']
            }
        }
    }

    my $acns = $U->simplereq(
        'open-ils.pcrud',
        'open-ils.pcrud.search.acn.atomic',
        $self->{session}->{authtoken},
        $search,
        $flesh
    );

    return $acns;
}

# Search for holds using the user, idvalue and selection_ou.
sub _hold_search {
    my $self = shift;
    my $user = shift;
    my $target = shift;
    my $selection_ou = shift;

    my $hold;

    # Retrieve all of the user's active holds, and then search them in Perl.
    my $holds_list = $U->simplereq(
        'open-ils.circ',
        'open-ils.circ.holds.retrieve',
        $self->{session}->{authtoken},
        $user->id(),
        0
    );

    if ($holds_list && @$holds_list) {
        my @holds = grep {$_->target == $target && $_->selection_ou == $selection_ou->id()} @{$holds_list};
        # There should only be 1, at this point, if there are any.
        if (@holds) {
            $hold = $holds[0];
        }
    }

    return $hold;
}

# Standalone, "helper" functions.  These do not take an object or
# class reference.

# Check if a user is past their expiration date.
sub _expired {
    my $user = shift;
    my $expired = 0;

    # Users might not expire.  If so, they have no expire_date.
    if ($user->expire_date()) {
        my $expires = DateTime::Format::ISO8601->parse_datetime(
            cleanse_ISO8601($user->expire_date())
        )->epoch();
        my $now = DateTime->now()->epoch();
        $expired = $now > $expires;
    }

    return $expired;
}

# Creates a NCIP Problem from an event. Takes a string for the problem
# type, the event hashref (or a string to use for the detail), and
# optional arguments for the ProblemElement and ProblemValue fields.
sub _problem_from_event {
    my ($type, $evt, $element, $value) = @_;

    my $detail;

    # Check the event.
    if (ref($evt)) {
        my ($textcode, $desc);

        # Get the textcode, if available. Otherwise, use the ilsevent
        # "id," if available.
        if ($evt->{textcode}) {
            $textcode = $evt->{textcode};
        } elsif ($evt->{ilsevent}) {
            $textcode = $evt->{ilsevent};
        }

        # Get the description. We favor translated descriptions over
        # the English in ils_events.xml.
        if ($evt->{desc}) {
            $desc = $evt->{desc};
        }

        # Check if $type was set. As an "undocumented" feature, you
        # can pass undef, and we'll use the textcode from the event.
        unless ($type) {
            if ($textcode) {
                $type = $textcode;
            }
        }

        # Set the detail from some combination of the above.
        if ($desc) {
            $detail = $desc;
        } elsif ($textcode eq 'PERM_FAILURE') {
            if ($evt->{ilsperm}) {
                $detail = "Permission denied: " . $evt->{ilsperm};
                $detail =~ s/\.override$//;
            }
        } elsif ($textcode) {
            $detail = "ILS returned $textcode error.";
        } else {
            $detail = 'Detail not available.';
        }

    } else {
        $detail = $evt;
    }

    return NCIP::Problem->new(
        {
            ProblemType => ($type) ? $type : 'Temporary Processing Failure',
            ProblemDetail => ($detail) ? $detail : 'Detail not available.',
            ProblemElement => ($element) ? $element : 'NULL',
            ProblemValue => ($value) ? $value : 'NULL'
        }
    );
}

# "Fix" dates for output so they validate against the schema
sub _fix_date {
    my $date = shift;
    my $out = DateTime::Format::ISO8601->parse_datetime(cleanse_ISO8601($date));
    $out->set_time_zone('UTC');
    return $out->iso8601();
}

1;
