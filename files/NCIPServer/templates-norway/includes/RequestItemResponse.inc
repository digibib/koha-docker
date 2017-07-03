<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
	<!-- Usage in NNCIPP 1.0 is in use-case 2, call #3: The response, on a users request for a item -->
	<ns1:RequestItemResponse>
		<!-- The ResponseHeader, stating from- and to-agency, is mandatory -->
		<ns1:ResponseHeader>
			<!-- Owner Library -->
			<ns1:FromAgencyId>
				<ns1:AgencyId>[% data.FromAgencyId %]</ns1:AgencyId>
			</ns1:FromAgencyId>
			<!-- Home Library -->
			<ns1:ToAgencyId>
				<ns1:AgencyId>[% data.ToAgencyId %]</ns1:AgencyId>
			</ns1:ToAgencyId>
		</ns1:ResponseHeader>
		<!-- The RequestId must be equal to the one created by the initializing AgencyId -->
		<ns1:RequestId>
			<!-- The initializing AgencyId must be part of the RequestId -->
			<ns1:AgencyId>[% data.RequestId.AgencyId %]</ns1:AgencyId>
			<!-- The RequestIdentifierValue must be part of the RequestId-->
			<ns1:RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue %]</ns1:RequestIdentifierValue>
		</ns1:RequestId>
		<!-- The ItemId must uniquely identify the lended Item in the scope of the FromAgencyId -->
		<ns1:ItemId>
			<!-- All Items must have a scannable Id either a RFID or a Barcode or Both. -->
			<!-- In the case of both, start with the Barcode, use colon and no spaces as delimitor.-->
			<ns1:ItemIdentifierType>[% data.ItemId.ItemIdentifierType %]</ns1:ItemIdentifierType>
			<ns1:ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue %]</ns1:ItemIdentifierValue>
		</ns1:ItemId>
		<!-- The UserId must be equal to the one in the initializing RequestItem msg -->
		<ns1:UserId>
			<ns1:UserIdentifierValue>[% data.UserId.UserIdentifierValue %]</ns1:UserIdentifierValue>
		</ns1:UserId>
		<!-- The RequestType must be one of the following: -->
		<!-- Physical, a loan (of a physical item, create a reservation if not available) -->
		<!-- Non-Returnable, a copy of a physical item - that is not required to return -->
		<!-- PhysicalNoReservation, a loan (of a physical item), do NOT create a reservation if not available -->
		<!-- LII, a patron initialized physical loan request, threat as a physical loan request -->
		<!-- LIINoReservation, a patron initialized physical loan request, do NOT create a reservation if not available -->
		<!-- Depot, a border case; some librarys get a box of (foreign language) books from the national library -->
		<!-- If your library dont recive 'Depot'-books; just respond with a "Unknown Value From Known Scheme"-ProblemType -->
		<ns1:RequestType>[% data.RequestType %]</ns1:RequestType>
		<!-- RequestScopeType is mandatory and must be "Title", signaling that the request is on title-level -->
		<!-- (and not Item-level - even though the request was on a Id that uniquely identify the requested Item) -->
		<ns1:RequestScopeType>Title</ns1:RequestScopeType>
		<!-- Include ItemOptionalFields.BibliographicDescription if the request asked about Bibliographic data -->
		<ns1:ItemOptionalFields>
			<!-- BibliographicDescription is used to describe the ItemId -->
			<ns1:BibliographicDescription>
				<!-- The following elements is mandatory, populate the elements according to MARC21 codes -->
				<ns1:Author>[% data.ItemOptionalFields.Author | xml %]</ns1:Author>
				<ns1:PlaceOfPublication>[% data.ItemOptionalFields.PlaceOfPublication %]</ns1:PlaceOfPublication>
				<ns1:PublicationDate>[% data.ItemOptionalFields.PublicationDate %]</ns1:PublicationDate>
				<ns1:Publisher>[% data.ItemOptionalFields.Publisher %]</ns1:Publisher>
				<ns1:Title>[% data.ItemOptionalFields.Title %]</ns1:Title>
				<!-- The following line is required by Alma. -->
				<ns1:BibliographicLevel>[% data.ItemOptionalFields.BibliographicLevel %]</ns1:BibliographicLevel>
				<ns1:Language>[% data.ItemOptionalFields.Language %]</ns1:Language>
				<ns1:MediumType>[% data.ItemOptionalFields.MediumType %]</ns1:MediumType>
			</ns1:BibliographicDescription>
		</ns1:ItemOptionalFields>
	</ns1:RequestItemResponse>
</ns1:NCIPMessage>

