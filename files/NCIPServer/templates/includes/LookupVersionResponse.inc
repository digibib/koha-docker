<FromAgencyId>
<AgencyId>[% data.fromagencyid | xml %]</AgencyId>
</FromAgencyId>
<ToAgencyId>
<AgencyId>[% data.toagencyid | xml %]</AgencyId>
</ToAgencyId>
[% FOREACH version IN data.versions -%]
<VersionSupported>[% version | xml %]</VersionSupported>
[% END -%]
