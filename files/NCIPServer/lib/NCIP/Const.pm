# ---------------------------------------------------------------
# Copyright © 2014 Jason J.A. Stephenson <jason@sigio.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# ---------------------------------------------------------------
package NCIP::Const;

# Constants for NCIP.pm and family.

# We don't use Exporter, so we must refer to these with NCIP::Const::
# prefix.

# Versions of NCIP that we support as indicated by a list of schema
# URIs.
use constant SUPPORTED_VERSIONS => (
    'http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd',
);

# Messages for which AuthenticationInput are valid.
use constant AUTHENTICATIONINPUT_MESSAGES => (
    'LookupUser', 'RenewItem', 'CheckOutItem', 'RequestItem',
);
1;
