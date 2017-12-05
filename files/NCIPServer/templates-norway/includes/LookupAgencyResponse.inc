<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
    <ns1:LookupAgencyResponse>
        <ns1:ResponseHeader>
            <ns1:FromAgencyId>
                <ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
            </ns1:FromAgencyId>
            <ns1:ToAgencyId>
                <ns1:AgencyId>[% data.toagencyid | xml %]</ns1:AgencyId>
            </ns1:ToAgencyId>
        </ns1:ResponseHeader>
        <ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
        <ns1:OrganizationNameInformation>
            <ns1:OrganizationNameType>[% data.orgtype %] Library</ns1:OrganizationNameType>
            <ns1:OrganizationName>[% data.library.branchname | xml %]</ns1:OrganizationName>
        </ns1:OrganizationNameInformation>
        <ns1:AgencyAddressInformation>
            <ns1:AgencyAddressRoleType>Ship To</ns1:AgencyAddressRoleType>
            <ns1:PhysicalAddress>
                <ns1:StructuredAddress>
                    <ns1:Street>[% data.library.branchaddress1 | xml %]</ns1:Street>
                    <ns1:Region>[% data.library.branchcity | xml %]</ns1:Region>
                    <ns1:Country>Norway</ns1:Country>
                    <ns1:PostalCode>[% data.library.branchzip | xml %]</ns1:PostalCode>
                </ns1:StructuredAddress>
                <ns1:PhysicalAddressType/>
            </ns1:PhysicalAddress>
        </ns1:AgencyAddressInformation>
        <ns1:ApplicationProfileSupportedType>[% data.applicationprofilesupportedtype | xml %]</ns1:ApplicationProfileSupportedType>
    </ns1:LookupAgencyResponse>
</ns1:NCIPMessage>
