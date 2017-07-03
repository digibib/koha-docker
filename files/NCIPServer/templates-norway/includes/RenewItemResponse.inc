<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
	<!-- Usage in NNCIPP 1.0 is in use-case 4, call #9: ACK "Home library informs Owner library that a patron has requested a renewed loan on a item." -->
	<ns1:RenewItemResponse>
		<!-- The InitiationHeader, stating from- and to-agency, is mandatory. -->
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
		<ns1:ItemId>
			<!-- All Items must have a scannable Id either a RFID or a Barcode or Both. -->
			<!-- In the case of both, start with the Barcode, use colon and no spaces as delimitor.-->
			<ns1:ItemIdentifierType>[% data.ItemId.ItemIdentifierType | xml %]</ns1:ItemIdentifierType>
			<ns1:ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ns1:ItemIdentifierValue>
		</ns1:ItemId>
		<!-- The UserId must be uniqe in the scope of Home Library -->
		<ns1:UserId>
			<ns1:UserIdentifierValue>[% data.UserId.UserIdentifierValue | xml %]</ns1:UserIdentifierValue>
		</ns1:UserId>
		<!-- Must use dateTime as defined in ISO 8601-2004 -->
		<ns1:DateDue>[% data.DateDue | xml %]</ns1:DateDue>
		<!-- Example timeDate set the DueDate to include the 31st of january 2015. -->
	</ns1:RenewItemResponse>
	<!-- [% data.diag %] -->
</ns1:NCIPMessage>
