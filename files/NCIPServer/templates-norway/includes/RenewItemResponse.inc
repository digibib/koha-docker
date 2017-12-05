<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
	<ns1:RenewItemResponse>
		<ns1:ResponseHeader>
			<ns1:FromAgencyId>
				<ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
			</ns1:FromAgencyId>
			<ns1:ToAgencyId>
				<ns1:AgencyId>[% data.toagencyid | xml %]</ns1:AgencyId>
			</ns1:ToAgencyId>
		</ns1:ResponseHeader>
		<ns1:ItemId>
			<ns1:ItemIdentifierType>[% data.ItemId.ItemIdentifierType | xml %]</ns1:ItemIdentifierType>
			<ns1:ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ns1:ItemIdentifierValue>
		</ns1:ItemId>
		<ns1:UserId>
			<ns1:UserIdentifierValue>[% data.UserId.UserIdentifierValue | xml %]</ns1:UserIdentifierValue>
		</ns1:UserId>
		<!-- dateTime as defined in ISO 8601-2004 -->
		<ns1:DateDue>[% data.DateDue | xml %]</ns1:DateDue>
	</ns1:RenewItemResponse>
</ns1:NCIPMessage>
