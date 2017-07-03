<RequestId>
[% IF data.RequestId.AgencyId -%]
<AgencyId>[% data.RequestId.AgencyId | xml %]</AgencyId>
[% END -%]
[% IF data.RequestId.RequestIdentifierType -%]
<RequestIdentifierType>[% data.RequestId.RequestIdentifierType | xml %]</RequestIdentifierType>
[% END -%]
<RequestIdentifierValue>[% data.RequestId.RequestIdentifierValue | xml %]</RequestIdentifierValue>
</RequestId>
