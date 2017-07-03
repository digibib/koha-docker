[%-
    INCLUDE "includes/ItemId.inc";
    IF data.UserId;
        INCLUDE "includes/UserId.inc";
    END;
    IF data.DateDue
-%]
<ns1:DateDue>[% data.DateDue | xml %]</ns1:DateDue>
[%
    END;
    INCLUDE "includes/ItemOptionalFields.inc";
    INCLUDE "includes/UserOptionalFields.inc";
-%]
