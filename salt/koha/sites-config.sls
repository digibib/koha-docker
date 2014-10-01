##########
# KOHA Sites Config
##########

# koha-sites.conf includes port settings and MARC framework used in all new instances
/etc/koha/koha-sites.conf:
  file.managed:
    - source: salt://koha/files/koha-sites.conf
    - template: jinja
    - context:
      ServerName: {{ pillar['koha']['instance'] }}

# admin login user/pass file
/etc/koha/passwd:
  file.managed:
    - source: salt://koha/files/passwd
    - mode: 0600
    - template: jinja
    - context:
      ServerName: {{ pillar['koha']['instance'] }}

