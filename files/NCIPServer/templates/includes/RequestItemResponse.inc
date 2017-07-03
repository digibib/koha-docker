[%-
    IF data.RequestId.RequestIdentifierValue;
        INCLUDE "includes/RequestId.inc";
    END;
    IF data.ItemId.ItemIdentifierValue;
        INCLUDE "includes/ItemId.inc";
    END;
    INCLUDE "includes/UserId.inc";
    IF data.RequestType;
-%]
<RequestType>[% data.RequestType | xml %]</RequestType>
[%
    END;
    IF data.RequestScopeType;
%]
<RequestScopeType>[% data.RequestScopeType | xml %]</RequestScopeType>
[%
    END;
    INCLUDE "includes/ItemOptionalFields.inc";
    INCLUDE "includes/UserOptionalFields.inc"
-%]
