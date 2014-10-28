#!/usr/bin/perl

# rest.pl
#
# This script provide a RESTful webservice to interact with Koha.

use Modern::Perl;
use YAML;
use File::Basename;
use CGI::Application::Dispatch;
use List::MoreUtils qw(any);

my $conf_path = dirname($ENV{KOHA_CONF});
my $conf = YAML::LoadFile("$conf_path/rest/config.yaml");
$conf->{debug} //= 0;

# First of all, let's test if the client IP is allowed to use our service
# If the remote address is not allowed, redirect to 403
# my @AuthorizedIPs = $conf->{authorizedips} ? @{ $conf->{authorizedips} } : ();
# if ( !@AuthorizedIPs # If no filter set, allow access to no one!
#     or not any { $ENV{'REMOTE_ADDR'} eq $_ } @AuthorizedIPs # IP Check
#     ) {
#     CGI::Application::Dispatch->dispatch(
#         debug => $conf->{debug},
#         prefix => 'Koha::REST',
#         table => [
#             '*' => { app => 'Auth', rm => 'forbidden' },
#             '/' => { app => 'Auth', rm => 'forbidden' },
#         ],
#     );
#     exit 0;
# }


use Koha::REST::Dispatch;

Koha::REST::Dispatch->dispatch(
    debug => $conf->{debug},
);

__END__

=head1 NAME

rest.pl

=head1 DESCRIPTION

This script provide a RESTful webservice to interact with Koha.

=head1 SERVICES

=head2 Infos

=head3 GET branches

=over 2

Get the list of branches

Response:

=over 2

a JSON array that contains branches. Each branch is described by a hash with the
following keys:

=over 2

=item * code: internal branch identifier

=item * name: branch name

=back

=back

=back

=head2 User

=head3 GET user/byid/:borrowernumber/holds

=over 2

Get holds of a user, given his id.

Required parameters:

=over 2

=item * borrowernumber: Patron id.

=back

Response:

=over 2

a JSON array that contains holds. Each hold is described by a hash with the
following keys:

=over 2

=item * hold_id: internal hold identifier.

=item * rank: position of the patron in reserve queue.

=item * reservedate: date of reservation.

=item * biblionumber: internal biblio identifier.

=item * title: title of bibliographic record.

=item * branchcode: pickup library code.

=item * branchname: pickup library name.

=item * found: 'W' if item is awaiting for pickup.

=back

If reserve is at item level, there are two additional keys:

=over 2

=item * itemnumber: internal item identifier.

=item * barcode: barcode of item.

=back

=back

=back

=head3 GET user/:user_name/holds

=over 2

Get holds of a user, given his username.

Required parameters:

=over 2

=item * user_name: Patron username.

=back

Response:

=over 2

a JSON array that contains holds. Each hold is described by a hash with the
following keys:

=over 2

=item * hold_id: internal hold identifier.

=item * rank: position of the patron in reserve queue.

=item * reservedate: date of reservation.

=item * biblionumber: internal biblio identifier.

=item * title: title of bibliographic record.

=item * branchcode: pickup library code.

=item * branchname: pickup library name.

=item * found: 'W' if item is awaiting for pickup.

=back

If reserve is at item level, there are two additional keys:

=over 2

=item * itemnumber: internal item identifier.

=item * barcode: barcode of item.

=back

=back

=back

=head3 GET user/byid/:borrowernumber/issues

=over 2

Get issues of a user, given his id.

Required parameters:

=over 2

=item * borrowernumber: Patron id.

=back

Response:

=over 2

a JSON array that contains issues. Each issue is described by a hash with the
following keys:

=over 2

=item * borrowernumber: internal patron identifier.

=item * biblionumber: internal biblio identifier.

=item * title: title of bibliographic record.

=item * itemnumber: internal item identifier.

=item * barcode: barcode of item.

=item * branchcode: pickup library code.

=item * issuedate: date of issue.

=item * date_due: the date the item is due.

=item * renewable: is the issue renewable ? (boolean)

=back

If the issue is not renewable, there is one additional key:

=over 2

=item * reasons_not_renewable: 2 possible values:

=over 2

=item * 'on_reserve': item is on hold.

=item * 'too_many': issue was renewed too many times.

=back

=back

=back

=back

=head3 GET user/:user_name/issues

=over 2

Get issues of a user, given his username.

Required parameters:

=over 2

=item * user_name: Patron username.

=back

Response:

=over 2

a JSON array that contains issues. Each issue is described by a hash with the
following keys:

=over 2

=item * borrowernumber: internal patron identifier.

=item * biblionumber: internal biblio identifier.

=item * title: title of bibliographic record.

=item * itemnumber: internal item identifier.

=item * barcode: barcode of item.

=item * branchcode: pickup library code.

=item * issuedate: date of issue.

=item * date_due: the date the item is due.

=item * renewable: is the issue renewable ? (boolean)

=back

If the issue is not renewable, there is one additional key:

=over 2

=item * reasons_not_renewable: 2 possible values:

=over 2

=item * 'on_reserve': item is on hold.

=item * 'too_many': issue was renewed too many times.

=back

=back

=back

=back

=head3 GET user/:user_name/issues_history

=over 2

Get issues history for a user.

Required parameters:

=over 2

=item * user_name: Patron username.

=back

Response:

=over 2

a JSON array that contains issues. Each issue is described by a hash.

=back

=back

=head3 GET user/byid/:borrowernumber/issues_history

=over 2

Get issues history for a user.

Required parameters:

=over 2

=item * borrowernumber: Patron borrowernumber.

=back

Response:

=over 2

a JSON array that contains issues. Each issue is described by a hash.

=back

=back

=head3 GET user/today

=over 2

Get information about patrons enrolled today

Required parameters:

=over 2

None

=back

Response:

=over 2

a JSON array containing all informations about patrons enrolled today and it's extended attributes

=back

=back

=head3 GET user/all

=over 2

Get information about all patrons

Required parameters:

=over 2

None

=back

Response:

=over 2

a JSON array containing all informations about all patrons, and their extended attributes

Warning, this file will be large !!!

=back

=back

=head3 POST user

Create new user

Required parameters:

=over 2

=item * data: A JSON string which should be an object where keys are names of
fields and values are values for those fields.

Available fields: cardnumber, surname, firstname, title,
othernames, initials, streetnumber, streettype, address, address2, city, state,
zipcode, country, email, phone, mobile, fax, emailpro, phonepro,
B_streetnumber, B_streettype, B_address, B_address2, B_city, B_state,
B_zipcode, B_country, B_email, B_phone, dateofbirth, branchcode, categorycode,
dateenrolled, dateexpiry, gonenoaddress, lost, debarred, debarredcomment,
contactname, contactfirstname, contacttitle, guarantorid, borrowernotes,
relationship, ethnicity, ethnotes, sex, password, flags, userid, opacnote,
contactnote, sort1, sort2, altcontactfirstname, altcontactsurname,
altcontactaddress1, altcontactaddress2, altcontactaddress3, altcontactstate,
altcontactzipcode, altcontactcountry, altcontactphone, smsalertnumber, privacy

If categorycode is not given, system preference
PatronSelfRegistrationDefaultCategory is used.

=back

Response:

=over 2

A JSON object with the following keys:

=over 2

=item * borrowernumber: Borrowernumber of newly created user.

=back

=back

=head3 PUT user/:user_name

=over 2

Modify user's informations

Required parameters:

=over 2

=item * user_name: username (userid) of user to modify.

=item * data: A JSON string which should be an object where keys are names of fields to modify and values are new values for those fields.
Available fields: cardnumber, surname, firstname, title,
othernames, initials, streetnumber, streettype, address, address2, city, state,
zipcode, country, email, phone, mobile, fax, emailpro, phonepro,
B_streetnumber, B_streettype, B_address, B_address2, B_city, B_state,
B_zipcode, B_country, B_email, B_phone, dateofbirth, branchcode, categorycode,
dateenrolled, dateexpiry, gonenoaddress, lost, debarred, debarredcomment,
contactname, contactfirstname, contacttitle, guarantorid, borrowernotes,
relationship, ethnicity, ethnotes, sex, password, flags, userid, opacnote,
contactnote, sort1, sort2, altcontactfirstname, altcontactsurname,
altcontactaddress1, altcontactaddress2, altcontactaddress3, altcontactstate,
altcontactzipcode, altcontactcountry, altcontactphone, smsalertnumber, privacy

=back

Response:

=over 2

A JSON object with the following keys:

=over 2

=item * success: A boolean that indicates if modification succeeded or not.

=item * modified_fields: An object that indicates which fields were modified and the new value for each field.

=back

=back

=back

=head3 DELETE user/:user_name

=over 2

Delete user

Required parameters:

=over 2

=item * user_name: username (userid) of user to delete.

=back

=back


=head2 Biblio

=head3 GET biblio/:biblionumber/items

=over 2

Get items of a bibliographic record.

Required parameters:

=over 2

=item * biblionumber: internal biblio identifier.

=back

Optional parameters:

=over 2

=item * reserves: 1 to retrieve the reserves for each item, 0 otherwise (default: 0)

Response:

=over 2

a JSON array that contains items. Each item is described by a hash with the
following keys:

=over 2

=item * itemnumber: internal item identifier.

=item * holdingbranch: holding library code.

=item * holdingbranchname: holding library name.

=item * homebranch: home library code.

=item * homebranchname: home library name.

=item * withdrawn: is the item withdrawn ?

=item * notforloan: is the item not available for loan ?

=item * onloan: date of loan if item is on loan.

=item * location: item location.

=item * itemcallnumber: item call number.

=item * date_due: due date if item is on loan.

=item * barcode: item barcode.

=item * itemlost: is item lost ?

=item * damaged: is item damaged ?

=item * stocknumber: item stocknumber.

=item * itype: item type.

=item * reserves: if optional parameter 'reserves' is set to 1, this key contains an array of all reserves for this item

=back

=back

=back

=back

=head3 GET biblio/:biblionumber/holdable

=over 2

Check if a biblio is holdable.

Required parameters:

=over 2

=item * biblionumber: internal biblio identifier.

=back

Optional parameters:

=over 2

=item * borrowernumber: internal patron identifier. It is optional but highly
recommended, as no check is performed without it and a true value is always
returned.

=item * itemnumber: internal item identifier. If given, check is done on item
instead of biblio.

=back

Response:

=over 2

a JSON hash that contains the following keys:

=over 2

=item * is_holdable: is the biblio holdable? (boolean)

=item * reasons: reasons why the biblio can't be reserved, if appropriate.
Actually there is no valid reasons...

=back

=back

=back

=head3 GET biblio/:biblionumber/items_holdable_status

=over 2

Check if items of a bibliographic record are holdable.

Required parameters:

=over 2

=item * biblionumber: internal biblio identifier.

=back

Optional parameters:

=over 2

=item * borrowernumber: Patron borrowernumber. It is optional but highly
recommended. If not given, all items will be marked as not holdable.

=item * user_name: Patron username. Only used to find borrowernumber if this one
is not given.

=back

Response:

=over 2

a JSON hash where keys are itemnumbers. Each element of this hash contain
another hash whose keys are:

=over 2

=item * is_holdable: is the item holdable ? (boolean)

=item * reasons: reasons why the biblio can't be reserved, if appropriate.
Actually there is no valid reasons...

=back

=back

=back

=head2 Item

=head3 GET item/:itemnumber/holdable

=over 2

Check if an item is holdable.

Required parameters:

=over 2

=item * itemnumber: internal item identifier.

=back

Optional parameters:

=over 2

=item * user_name: patron username. It is optional but highly recommended. If
not given, item will be marked as not holdable.

=back

Response:

=over 2

a JSON hash with following keys:

=over 2

=item * is_holdable: is item holdable ? (boolean)

=item * reasons: reasons why the biblio can't be reserved, if appropriate.
Actually there is no valid reasons...

=back

=back

=back

=head2 Auth

=head3 PUT auth/change_password

=over 2

Change user password.

Required parameters:

=over 2

=item * user_name: patron username.

=item * new_password: wanted password.

=back

Response:

=over 2

a JSON array which contains one hash with the following keys:

=over 2

=item * success: does the operation succeeded ?

=back

=back

=back

=head2 Suggestions

=head3 GET /suggestions

=over 2

Get all suggestions (optionally filtered using parameters)

Optional parameters are the same as C4::Suggestions::SearchSuggestions. Please refer to documentation of this subroutine.

Examples:

=over 2

=item * GET /suggestions (returns all suggestions)

=item * GET /suggestions?suggestedby=3 (returns all suggestions suggested by borrower 3)

=item * GET /suggestions?suggesteddate_from=2013-01-01&suggesteddate_to=2013-12-31 (returns all suggestions made in 2013)

=back

Response:

=over 2

a JSON array which contains one JSON object for each suggestion returned.

=back

=back

=head3 GET /suggestions/:suggestionid

=over 2

Get one suggestion from its identifier.

Required parameters:

=over 2

=item * suggestionid: Suggestion identifier

=back

Examples:

=over 2

=item * GET /suggestions/3

=back

Response:

=over 2

a JSON object which describes the suggestion.

=back

=back

=head3 POST /suggestions

=over 2

Create a new suggestion.

Required parameters:

=over 2

=item * data: a JSON-formatted string which describes the suggestion to create.
Allowed keys are:
suggestedby, suggesteddate, managedby, manageddate, acceptedby, accepteddate,
rejectedby, rejecteddate, STATUS, note, author, title, copyrightdate,
publishercode, date, volumedesc, publicationyear, place, isbn, mailoverseeing,
biblionumber, reason, patronreason, budgetid, branchcode, collectiontitle,
itemtype, quantity, currency, price, total

=back

Examples:

=over 2

=item * POST /suggestions

POST: data={"suggestedby":"2", "title":"1984", "author":"George Orwell"}

=back

Response:

=over 2

a JSON object which describes the created suggestion.

=back

=back

=head3 PUT /suggestions/:suggestionid

=over 2

Modify an existing suggestion.

Required parameters:

=over 2

=item * suggestionid: Identifier of suggestion to modify

=item * data: a JSON object which contains the fields to modify.
Allowed keys are:
suggestedby, suggesteddate, managedby, manageddate, acceptedby, accepteddate,
rejectedby, rejecteddate, STATUS, note, author, title, copyrightdate,
publishercode, date, volumedesc, publicationyear, place, isbn, mailoverseeing,
biblionumber, reason, patronreason, budgetid, branchcode, collectiontitle,
itemtype, quantity, currency, price, total

=back

Examples:

=over 2

=item * PUT /suggestions/1

POST: data={"STATUS":"ACCEPTED"}

=back

Response:

=over 2

a JSON object which describes the modified suggestion.

=back

=back

=head3 DELETE /suggestions/:suggestionid

=over 2

Delete an existing suggestion.

Required parameters:

=over 2

=item * suggestionid: Identifier of suggestion to delete.

=back

Examples:

=over 2

=item * DELETE /suggestions/1

=back

Response:

=over 2

a JSON object with only one key: "success", which is true.

=back

=back

=cut
