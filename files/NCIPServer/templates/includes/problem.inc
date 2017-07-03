<Problem>
[% IF problem.Scheme -%]
<ProblemType Scheme="[% problem.Scheme | xml %]">
[% ELSE -%]
<ProblemType>
[% END -%]
[%- problem.ProblemType | xml %]</ProblemType>
<ProblemDetail>[% problem.ProblemDetail | xml %]</ProblemDetail>
<ProblemElement>[% problem.ProblemElement | xml %]</ProblemElement>
<ProblemValue>[% problem.ProblemValue | xml %]</ProblemValue>
</Problem>
