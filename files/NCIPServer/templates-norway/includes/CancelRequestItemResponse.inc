<?xml version="1.0" encoding="UTF-8"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
    <ns1:CancelRequestItemResponse>
        <ns1:ResponseHeader>
            <ns1:FromAgencyId>
                <ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
            </ns1:FromAgencyId>
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
        <ns1:RequestId>
            <ns1:AgencyId>[% data.RequestId.AgencyId | xml %]</ns1:AgencyId>
            <ns1:RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue | xml %]</ns1:RequestIdentifierValue>
        </ns1:RequestId>
        <ns1:ItemId>
            <ns1:ItemIdentifierType>[%  data.ItemId.ItemIdentifierType  | xml %]</ns1:ItemIdentifierType>
            <ns1:ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ns1:ItemIdentifierValue>
        </ns1:ItemId>
        <ns1:UserId>
            <ns1:UserIdentifierValue>[% data.UserId.UserIdentifierValue %]</ns1:UserIdentifierValue>
        </ns1:UserId>
        [% IF data.Problem %]
        </ns1:Ext>
        [% END %]
    </ns1:CancelRequestItemResponse>
</ns1:NCIPMessage>
