<ItemId>
[% IF data.ItemId.AgencyId -%]
<AgencyId>[% data.ItemId.AgencyId | xml %]</AgencyId>
[% END -%]
[% IF data.ItemId.ItemIdentifierType -%]
<ItemIdentifierType>[% data.ItemId.ItemIdentifierType | xml %]</ItemIdentifierType>
[% END -%]
<ItemIdentifierValue>[% data.ItemId.ItemIdentifierValue | xml %]</ItemIdentifierValue>
</ItemId>
