<UserId>
[% IF data.UserId.AgencyId -%]
<AgencyId>[% data.UserId.AgencyId | xml %]</AgencyId>
[% END -%]
[% IF data.UserId.UserIdentifierType -%]
<UserIdentifierType>[% data.UserId.UserIdentifierType | xml %]</UserIdentifierType>
[% END -%]
<UserIdentifierValue>[% data.UserId.UserIdentifierValue | xml %]</UserIdentifierValue>
</UserId>
