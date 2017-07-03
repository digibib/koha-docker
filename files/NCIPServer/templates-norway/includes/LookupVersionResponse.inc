<ns1:FromAgencyId>
<ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
</ns1:FromAgencyId>
<ns1:ToAgencyId>
<ns1:AgencyId>[% data.toagencyid | xml %]</ns1:AgencyId>
</ns1:ToAgencyId>
[% FOREACH version IN data.versions -%]
<ns1:VersionSupported>[% version | xml %]</ns1:VersionSupported>
[% END -%]
