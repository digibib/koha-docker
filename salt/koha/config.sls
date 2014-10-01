###########
# CONFIG changes - e g to switch to external database
###########

koha_common_cnf:
  file.managed:
    - name: /etc/mysql/koha-common.cnf
    - source: salt://koha/files/koha-common.cnf
    - template: jinja

# TODO: This should be parameterized or done with regex
# koha config from template
/etc/koha/sites/{{ pillar['koha']['instance'] }}/koha-conf.xml:
  file.managed:
    - source: salt://koha/files/koha-conf.xml.tmpl
    - group: {{ pillar['koha']['instance'] }}-koha
    - user: {{ pillar['koha']['instance'] }}-koha
    - template: jinja

# zebra internal password
/etc/koha/sites/{{ pillar['koha']['instance'] }}/zebra.passwd:
  file.managed:
    - source: salt://koha/files/zebra.passwd.tmpl
    - group: {{ pillar['koha']['instance'] }}-koha
    - user: {{ pillar['koha']['instance'] }}-koha
    - template: jinja