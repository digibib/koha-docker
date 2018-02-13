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
		[% IF data.ItemOptionalFields %]
		<ns1:ItemOptionalFields>
			<ns1:BibliographicDescription>
				<ns1:Author>[% data.ItemOptionalFields.Author | xml %]</ns1:Author>
				<ns1:PlaceOfPublication>[% data.ItemOptionalFields.PlaceOfPublication | xml %]</ns1:PlaceOfPublication>
				<ns1:PublicationDate>[% data.ItemOptionalFields.PublicationDate | xml %]</ns1:PublicationDate>
				<ns1:Publisher>[% data.ItemOptionalFields.Publisher | xml %]</ns1:Publisher>
				<ns1:Title>[% data.ItemOptionalFields.Title | xml  %]</ns1:Title>
				<!-- The following line is required by Alma. -->
				<ns1:BibliographicLevel>[% data.ItemOptionalFields.BibliographicLevel | xml %]</ns1:BibliographicLevel>
				<ns1:Language>[% data.ItemOptionalFields.Language | xml %]</ns1:Language>
				<ns1:MediumType>[% data.ItemOptionalFields.MediumType | xml %]</ns1:MediumType>
			</ns1:BibliographicDescription>
		</ns1:ItemOptionalFields>
		[% END %]
		<ns1:Ext>
			<ns1:UserId>
				<ns1:UserIdentifierValue>[% data.UserId %]</ns1:UserIdentifierValue>
			</ns1:UserId>
			[% IF data.ItemId %]
				<ns1:ItemId>
					<ns1:ItemIdentifierType>[% data.ItemId.ItemIdentifierType %]</ns1:ItemIdentifierType>
					<ns1:ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue %]</ns1:ItemIdentifierValue>
				</ns1:ItemId>
			[% END %]
			[% IF data.BibliographicId %]
				<ns1:BibliographicId>
					<ns1:BibliographicRecordId>
						<ns1:BibliographicRecordIdentifierCode>[% data.BibliographicId.BibliographicRecordIdentifierCode %]</ns1:BibliographicRecordIdentifierCode>
						<ns1:BibliographicRecordIdentifier>[% data.BibliographicId.BibliographicRecordIdentifier %]</ns1:BibliographicRecordIdentifier>
					</ns1:BibliographicRecordId>
				</ns1:BibliographicId>
			[% END %]
		</ns1:Ext>
	</ns1:ItemRequestedResponse>
</ns1:NCIPMessage>
