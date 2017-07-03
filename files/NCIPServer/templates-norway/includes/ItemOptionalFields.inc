[% IF data.ItemOptionalFields -%]
<ns1:ItemOptionalFields>
[% IF data.ItemOptionalFields.BibliographicDescription -%]
<ns1:BibliographicDescription>
[% IF data.ItemOptionalFields.BibliographicDescription.Author -%]
<ns1:Author>[% data.ItemOptionalFields.BibliographicDescription.Author | xml %]</ns1:Author>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.BibliographicItemId;
      id = data.ItemOptionalFields.BibliographicDescription.BibliographicItemId -%]
<ns1:BibliographicItemId>
<ns1:BibliographicItemIdentifier>[% id.BibliographicItemIdentifier | xml %]</ns1:BibliographicItemIdentifier>
[% IF id.BibliographicItemIdentifierCode -%]
<ns1:BibliographicItemIdentifierCode>[% id.BibliographicItemIdentifierCode | xml %]</ns1:BibliographicItemIdentifierCode>
[% END -%]
</ns1:BibliographicItemId>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.BibliographicRecordId;
      id = data.ItemOptionalFields.BibliographicDescription.BibliographicRecordId -%]
<ns1:BibliographicRecordId>
<ns1:BibliographicRecordIdentifier>[% id.BibliographicRecordIdentifier | xml %]</ns1:BibliographicRecordIdentifier>
[% IF id.AgencyId -%]
<ns1:AgencyId>[% id.AgencyId | xml %]</ns1:AgencyId>
[% ELSIF id.BibliographicRecordIdentifierCode -%]
<ns1:BibliographicRecordIdentifierCode>[% id.BibliographicRecordIdentifierCode | xml %]</ns1:BibliographicRecordIdentifierCode>
[% END -%]
</ns1:BibliographicRecordId>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.Edition -%]
<ns1:Edition>[% data.ItemOptionalFields.BibliographicDescription.Edition | xml %]</ns1:Edition>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.PublicationDate -%]
<ns1:PublicationDate>[% data.ItemOptionalFields.BibliographicDescription.PublicationDate | xml %]</ns1:PublicationDate>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.Publisher -%]
<ns1:Publisher>[% data.ItemOptionalFields.BibliographicDescription.Publisher | xml %]</ns1:Publisher>
[% END -%]
[% IF data.ItemOptionalFields.BibliographicDescription.Title -%]
<ns1:Title>[% data.ItemOptionalFields.BibliographicDescription.Title | xml %]</ns1:Title>
[% END -%]
</ns1:BibliographicDescription>
[% END -%]
[% IF data.ItemOptionalFields.ItemUseRestrictionType -%]
<ns1:ItemUseRestrictionType>[% data.ItemOptionalFields.ItemUseRestrictionType | xml %]</ns1:ItemUseRestrictionType>
[% END -%]
[% IF data.ItemOptionalFields.CirculationStatus -%]
<ns1:CirculationStatus>[% data.ItemOptionalFields.CirculationStatus | xml %]</ns1:CirculationStatus>
[% END -%]
[% IF data.ItemOptionalFields.ItemDescription -%]
<ns1:ItemDescription>
<ns1:CallNumber>[% data.ItemOptionalFields.ItemDescription.CallNumber | xml %]</ns1:CallNumber>
</ns1:ItemDescription>
[% END -%]
[% IF data.ItemOptionalFields.PhysicalCondition -%]
<ns1:PhysicalCondition>[% data.ItemOptionalFields.PhysicalCondition | xml %]</ns1:PhysicalCondition>
[% END -%]
[% IF data.ItemOptionalFields.DateDue -%]
<ns1:DateDue>[% data.ItemOptionalFields.DateDue | xml %]</ns1:DateDue>
[% END -%]
</ns1:ItemOptionalFields>
[% END -%]
