[%-
    IF data.RequestId.RequestIdentifierValue;
       INCLUDE "includes/RequestId.inc";
    END;
    IF data.ItemId.ItemIdentifierValue;
        INCLUDE "includes/ItemId.inc";
    END;
    INCLUDE "includes/UserId.inc";
    INCLUDE "includes/ItemOptionalFields.inc";
    INCLUDE "includes/UserOptionalFields.inc";
-%]
