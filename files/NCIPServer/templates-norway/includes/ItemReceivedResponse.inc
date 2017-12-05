<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
	<ns1:ItemReceivedResponse>
		<ns1:ResponseHeader>
			<ns1:FromAgencyId>
				<ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
	        </ns1:FromAgencyId>
            <ns1:ToAgencyId>
		        <ns1:AgencyId>[% data.toagencyid | xml %]</ns1:AgencyId>
			</ns1:ToAgencyId>
		</ns1:ResponseHeader>
		<ns1:Ext>
			<ns1:RequestId>
				<ns1:AgencyId>[% data.AgencyId %]</ns1:AgencyId>
				<ns1:RequestIdentifierValue>[% data.RequestIdentifierValue %]</ns1:RequestIdentifierValue>
			</ns1:RequestId>
		</ns1:Ext>
	</ns1:ItemReceivedResponse>
</ns1:NCIPMessage>
