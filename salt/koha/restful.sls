##########
# KOHA RESTFUL API
##########

restful_pkgs:
  pkg.installed:
    - pkgs:
      - libcgi-application-dispatch-perl
      - libtest-www-mechanize-cgiapp-perl

# Koha RESTful API script and Doc
# TODO: Should perhaps be included from separate container
/usr/share/koha/opac/cgi-bin/opac/rest.pl:
  file.managed:
    - source: salt://koha/files/rest.pl
    - mode: 644
