<ns1:ResponseHeader>
    <ns1:FromAgencyId>
        <ns1:AgencyId>[% header.FromAgencyId.AgencyId | xml %]</ns1:AgencyId>
    </ns1:FromAgencyId>
    <ns1:ToAgencyId>
        <ns1:AgencyId>[% header.ToAgencyId.AgencyId  | xml %]</ns1:AgencyId>
    </ns1:ToAgencyId>
</ns1:ResponseHeader>
