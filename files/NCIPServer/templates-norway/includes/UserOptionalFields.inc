[% IF data.UserOptionalFields -%]
<ns1:UserOptionalFields>
[% IF data.UserOptionalFields.NameInformation -%]
<ns1:NameInformation>
<ns1:PersonalNameInformation>
<ns1:StructuredPersonalUserName>
[% IF data.UserOptionalFields.NameInformation.Prefix -%]
<ns1:Prefix>[% data.UserOptionalFields.NameInformation.Prefix %]</ns1:Prefix>
[% END -%]
[% IF data.UserOptionalFields.NameInformation.GivenName -%]
<ns1:GivenName>[% data.UserOptionalFields.NameInformation.GivenName | xml %]</ns1:GivenName>
[% END -%]
[% IF data.UserOptionalFields.NameInformation.Initials -%]
<ns1:Initials>[% data.UserOptionalFields.NameInformation.Initials %]</ns1:Initials>
[% END -%]
<ns1:Surname>[% data.UserOptionalFields.NameInformation.Surname | xml %]</ns1:Surname>
[% IF data.UserOptionalFields.NameInformation.Suffix -%]
<ns1:Suffix>[% data.UserOptionalFields.NameInformation.Suffix %]</ns1:Suffix>
[% END -%]
</ns1:StructuredPersonalUserName>
</ns1:PersonalNameInformation>
</ns1:NameInformation>
[% END -%]
[% IF data.UserOptionalFields.UserAddressInformation -%]
[% FOREACH element IN data.UserOptionalFields.UserAddressInformation -%]
<ns1:UserAddressInformation>
<ns1:UserAddressRoleType>[% element.UserAddressRoleType | xml %]</ns1:UserAddressRoleType>
[% IF element.PhysicalAddress -%]
<ns1:PhysicalAddress>
<ns1:StructuredAddress>
<ns1:Line1>[% element.PhysicalAddress.StructuredAddress.Line1 | xml %]</ns1:Line1>
[% IF element.PhysicalAddress.StructuredAddress.Line2 -%]
<ns1:Line2>[% element.PhysicalAddress.StructuredAddress.Line2 | xml %]</ns1:Line2>
[% END -%]
[% IF element.PhysicalAddress.StructuredAddress.Locality -%]
<ns1:Locality>[% element.PhysicalAddress.StructuredAddress.Locality | xml %]</ns1:Locality>
[% END -%]
[% IF element.PhysicalAddress.StructuredAddress.Region -%]
<ns1:Region>[% element.PhysicalAddress.StructuredAddress.Region | xml %]</ns1:Region>
[% END -%]
[% IF element.PhysicalAddress.StructuredAddress.Country -%]
<ns1:Country>[% element.PhysicalAddress.StructuredAddress.Country | xml %]</ns1:Country>
[% END -%]
[% IF element.PhysicalAddress.StructuredAddress.PostalCode -%]
<ns1:PostalCode>[% element.PhysicalAddress.StructuredAddress.PostalCode | xml %]</ns1:PostalCode>
[% END -%]
</ns1:StructuredAddress>
<ns1:PhysicalAddressType>[% element.PhysicalAddress.Type | xml %]</ns1:PhysicalAddressType>
</ns1:PhysicalAddress>
[% ELSIF element.ElectronicAddress -%]
<ns1:ElectronicAddress>
<ns1:ElectronicAddressType>[% element.ElectronicAddress.Type | xml %]</ns1:ElectronicAddressType>
<ns1:ElectronicAddressData>[% element.ElectronicAddress.Data | xml %]</ns1:ElectronicAddressData>
</ns1:ElectronicAddress>
[% END -%]
</ns1:UserAddressInformation>
[% END -%]
[% END -%]
[% IF data.UserOptionalFields.UserLanguage -%]
[% FOREACH language IN data.UserOptionalFields.UserLanguage -%]
<ns1:UserLanguage>[% language | xml %]</ns1:UserLanguage>
[% END -%]
[% IF data.UserOptionalFields.UserPrivilege -%]
[% FOREACH privilege IN data.UserOptionalFields.UserPrivilege -%]
<ns1:UserPrivilege>
<ns1:AgencyId>[% privilege.AgencyId | xml -%]</ns1:AgencyId>
<ns1:AgencyUserPrivilegeType>[% privilege.AgencyUserPrivilegeType | xml %]</ns1:AgencyUserPrivilegeType>
[% IF privilege.ValidFromDate -%]
<ns1:ValidFromDate>[% privilege.ValidFromDate | xml %]</ns1:ValidFromDate>
[% END -%]
[% IF privilege.ValidToDate -%]
<ns1:ValidToDate>[% privilege.ValidToDate | xml %]</ns1:ValidToDate>
[% END -%]
[% IF privilege.UserPrivilegeDescription -%]
<ns1:UserPrivilegeDescription>[% privilege.UserPrivilegeDescription | xml %]</ns1:UserPrivilegeDescription>
[% END -%]
[% IF privilege.UserPrivilegeStatus -%]
<ns1:UserPrivilegeStatus>
<ns1:UserPrivilegeStatusType>[% privilege.UserPrivilegeStatus.UserPrivilegeStatusType | xml %]</ns1:UserPrivilegeStatusType>
[% IF privilege.UserPrivilegeStatus.DateOfUserPrivilegeStatus -%]
<ns1:DateOfUserPrivilegeStatus>[% privilege.UserPrivilegeStatus.DateOfUserPrivilegeStatus | xml %]</ns1:DateOfUserPrivilegeStatus>
[% END -%]
</ns1:UserPrivilegeStatus>
[% END -%]
</ns1:UserPrivilege>
[% END -%]
[% END -%]
[% END -%]
[% IF data.UserOptionalFields.BlockOrTrap -%]
[% FOREACH block IN data.UserOptionalFields.BlockOrTrap -%]
<ns1:BlockOrTrap>
<ns1:AgencyId>[% block.AgencyId | xml %]</ns1:AgencyId>
<ns1:BlockOrTrapType>[% block.BlockOrTrapType | xml %]</ns1:BlockOrTrapType>
[% IF block.ValidFromDate -%]
<ns1:ValidFromDate>[% block.ValidFromDate %]</ns1:ValidFromDate>
[% END -%]
[% IF block.ValidToDate -%]
<ns1:ValidToDate>[% block.ValidToDate %]</ns1:ValidToDate>
[% END %]
</ns1:BlockOrTrap>
[% END -%]
[% END -%]
</ns1:UserOptionalFields>
[% END -%]
