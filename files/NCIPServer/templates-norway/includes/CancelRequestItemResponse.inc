<?xml version="1.0" encoding="UTF-8"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
    <!-- Usage in NNCIPP 1.0 is in use-case 5, call #10: ACK "Home library informs Owner library that the requested Ioan is canceled" -->
    <ns1:CancelRequestItemResponse>
        <!-- The ResponseHeader, stating from- and to-agency, is mandatory. -->
        <ns1:ResponseHeader>
            <!-- Owner Library -->
            <ns1:FromAgencyId>
                <ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
            </ns1:FromAgencyId>
            <!-- Home Library -->
            <ns1:ToAgencyId>
                <ns1:AgencyId>[% data.toagencyid | xml %]</ns1:AgencyId>
            </ns1:ToAgencyId>
        </ns1:ResponseHeader>
        [% IF data.Problem %]
        <ns1:Problem>
            <ns1:ProblemType>[% data.Problem.ProblemType %]</ns1:ProblemType>
            <ns1:ProblemDetail>[% data.Problem.ProblemDetail %]</ns1:ProblemDetail>
        </ns1:Problem>
        <ns1:Ext>
        [% END %]
        <!-- The RequestId must be the one created by the initializing AgencyId in call #1 -->
        <ns1:RequestId>
            <ns1:AgencyId>[% data.RequestId.AgencyId | xml %]</ns1:AgencyId>
            <ns1:RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue | xml %]</ns1:RequestIdentifierValue>
        </ns1:RequestId>
        <!-- The ItemId must uniquely identify the requested Item in the scope of the ToAgencyId -->
        <ns1:ItemId>
            <!-- All Items must have a scannable Id either a RFID or a Barcode or Both. -->
            <!-- In the case of both, start with the Barcode, use colon and no spaces as delimitor.-->
            <ns1:ItemIdentifierType>[%  data.ItemId.ItemIdentifierType  | xml %]</ns1:ItemIdentifierType>
            <ns1:ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ns1:ItemIdentifierValue>
        </ns1:ItemId>
        <!-- Echo UserId, RequestId and ItemId to signal a positive loan cancel -->
        <ns1:UserId>
            <ns1:UserIdentifierValue>[% data.UserId.UserIdentifierValue %]</ns1:UserIdentifierValue>
        </ns1:UserId>
        [% IF data.Problem %]
        </ns1:Ext>
        [% END %]
    </ns1:CancelRequestItemResponse>
</ns1:NCIPMessage>
