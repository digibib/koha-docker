<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
    <!-- Usage in NNCIPP 1.0 is in use-case 1, call #1: The handshake; present yourselves! -->
    <ns1:LookupAgencyResponse>
        <!-- The ResponseHeader, stating from- and to-agency, is mandatory. -->
        <ns1:ResponseHeader>
            <!-- A libray -->
            <ns1:FromAgencyId>
                <ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
            </ns1:FromAgencyId>
            <!-- A libray -->
            <ns1:ToAgencyId>
                <ns1:AgencyId>[% data.toagencyid | xml %]</ns1:AgencyId>
            </ns1:ToAgencyId>
        </ns1:ResponseHeader>
        <!-- State whose information is presented -->
        <ns1:AgencyId>[% data.fromagencyid | xml %]</ns1:AgencyId>
        <!-- OrganizationNameInformation is recomended -->
        <ns1:OrganizationNameInformation>
            <!-- "Library Type" as recorded in BaseBibliotek -->
            <ns1:OrganizationNameType>[% data.orgtype %] Library</ns1:OrganizationNameType>
            <!-- "Name of library" as recorded in BaseBibliotek -->
            <ns1:OrganizationName>[% data.library.branchname | xml %]</ns1:OrganizationName>
        </ns1:OrganizationNameInformation>
        <!-- AgencyAddressInformation is recomended -->
        <!-- Appendix B in Part 2 defines different library addresses, it is recommended -->
        <!-- to support "Official" and "Ship To" addresses. -->
        <ns1:AgencyAddressInformation>
            <ns1:AgencyAddressRoleType>Ship To</ns1:AgencyAddressRoleType>
            <!-- Occurs 1 and only 1 time, and only if Electronic Address is not present, see page 70 in Part 1. -->
            <ns1:PhysicalAddress>
                <!-- It is recommended to use Structured Address, as it suits the norwegian address style best. -->
                <ns1:StructuredAddress>
                    <ns1:Street>[% data.library.branchaddress1 | xml %]</ns1:Street>
                    <ns1:Region>[% data.library.branchcity | xml %]</ns1:Region>
                    <ns1:Country>Norway</ns1:Country>
                    <ns1:PostalCode>[% data.library.branchzip | xml %]</ns1:PostalCode>
                </ns1:StructuredAddress>
                <!-- PhysicalAddressType is mandatory, but not in used. -->
                <ns1:PhysicalAddressType/>
            </ns1:PhysicalAddress>
        </ns1:AgencyAddressInformation>
        <!-- ApplicationProfileSupportedType state what versions of NNCIPP this server comply with. -->
        <ns1:ApplicationProfileSupportedType>[% data.applicationprofilesupportedtype | xml %]</ns1:ApplicationProfileSupportedType>
    </ns1:LookupAgencyResponse>
</ns1:NCIPMessage>
