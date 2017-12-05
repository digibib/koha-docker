<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
	<ns1:ItemRequestedResponse>
		<ns1:ResponseHeader>
			<ns1:FromAgencyId>
				<ns1:AgencyId>[% data.FromAgencyId %]</ns1:AgencyId>
			</ns1:FromAgencyId>
			<ns1:ToAgencyId>
				<ns1:AgencyId>[% data.ToAgencyId %]</ns1:AgencyId>
			</ns1:ToAgencyId>
		</ns1:ResponseHeader>
		<ns1:Ext>
			<ns1:UserId>
				<ns1:UserIdentifierValue>[% data.UserId %]</ns1:UserIdentifierValue>
			</ns1:UserId>
			<ns1:ItemId>
				<ns1:ItemIdentifierValue>[% data.ItemId %]</ns1:ItemIdentifierValue>
			</ns1:ItemId>
		</ns1:Ext>
	</ns1:ItemRequestedResponse>
</ns1:NCIPMessage>
