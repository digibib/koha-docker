<ns1:ItemId>
[% IF data.ItemId.AgencyId -%]
<ns1:AgencyId>[% data.ItemId.AgencyId | xml %]</ns1:AgencyId>
[% END -%]
[% IF data.ItemId.ItemIdentifierType -%]
<ns1:ItemIdentifierType>[% data.ItemId.ItemIdentifierType | xml %]</ns1:ItemIdentifierType>
[% END -%]
<ns1:ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ns1:ItemIdentifierValue>
</ns1:ItemId>
