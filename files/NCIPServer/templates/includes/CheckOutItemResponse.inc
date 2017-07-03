[%-
    INCLUDE "includes/ItemId.inc";
    IF data.UserId;
        INCLUDE "includes/UserId.inc";
    END;
    IF data.DateDue
-%]
<DateDue>[% data.DateDue | xml %]</DateDue>
[%
    END;
    INCLUDE "includes/ItemOptionalFields.inc";
    INCLUDE "includes/UserOptionalFields.inc";
-%]
