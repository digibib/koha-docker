<?xml version="1.0" encoding="UTF-8"?>
<ns1:NCIPMessage xmlns:ns1="http://www.niso.org/2008/ncip" ns1:version="http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.niso.org/2008/ncip http://www.niso.org/schemas/ncip/v2_02/ncip_v2_02.xsd">
<ns1:Problem>
    [% IF problem.ProblemType    %]<ns1:ProblemType>[%    problem.ProblemType    | xml %]</ns1:ProblemType>[% END %]
    [% IF problem.ProblemDetail  %]<ns1:ProblemDetail>[%  problem.ProblemDetail  | xml %]</ns1:ProblemDetail>[% END %]
    [% IF problem.ProblemElement %]<ns1:ProblemElement>[% problem.ProblemElement | xml %]</ns1:ProblemElement>[% END %]
    [% IF problem.ProblemValue   %]<ns1:ProblemValue>[%   problem.ProblemValue   | xml %]</ns1:ProblemValue>[% END %]
</ns1:Problem>
</ns1:NCIPMessage>
