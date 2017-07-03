<ns1:RequestId>
[% IF data.RequestId.AgencyId -%]
<ns1:AgencyId>[% data.RequestId.AgencyId | xml %]</ns1:AgencyId>
[% END -%]
[% IF data.RequestId.RequestIdentifierType -%]
<ns1:RequestIdentifierType>[% data.RequestId.RequestIdentifierType | xml %]</ns1:RequestIdentifierType>
[% END -%]
<ns1:RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue | xml %]</ns1:RequestIdentifierValue>
</ns1:RequestId>
