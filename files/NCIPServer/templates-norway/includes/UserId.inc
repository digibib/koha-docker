<ns1:UserId>
[% IF data.UserId.AgencyId -%]
<ns1:AgencyId>[% data.UserId.AgencyId | xml %]</ns1:AgencyId>
[% END -%]
[% IF data.UserId.UserIdentifierType -%]
<ns1:UserIdentifierType>[% data.UserId.UserIdentifierType | xml %]</ns1:UserIdentifierType>
[% END -%]
<ns1:UserIdentifierValue>[% data.UserId.UserIdentifierValue | xml %]</ns1:UserIdentifierValue>
</ns1:UserId>
