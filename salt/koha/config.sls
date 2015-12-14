###########
# CONFIG changes - e g to switch to external database
###########

# TODO: This should be parameterized or done with regex
# koha config from template
/etc/koha/sites/{{ pillar['koha']['instance'] }}/koha-conf.xml:
  file.managed:
    - source: salt://koha/files/koha-conf.xml.tmpl
    - group: {{ pillar['koha']['instance'] }}-koha
    - user: {{ pillar['koha']['instance'] }}-koha
    - template: jinja

/etc/koha/sites/{{ pillar['koha']['instance'] }}/log4perl.conf:
  file.managed:
    - source: salt://koha/files/log4perl.conf
    - group: {{ pillar['koha']['instance'] }}-koha
    - user: {{ pillar['koha']['instance'] }}-koha
    - template: jinja

# zebra internal password
config_zebrapass:
  file.managed:
    - name: /etc/koha/sites/{{ pillar['koha']['instance'] }}/zebra.passwd
    - stateful: True
    - source: salt://koha/files/zebra.passwd.tmpl
    - group: {{ pillar['koha']['instance'] }}-koha
    - user: {{ pillar['koha']['instance'] }}-koha
    - template: jinja

config_apacheinstance:
  file.managed:
    - name: /etc/apache2/sites-available/{{ pillar['koha']['instance'] }}.conf
    - stateful: True
    - source: salt://koha/files/apache.tmpl
    - template: jinja
    - context:
      OpacPort: 8080
      IntraPort: 8081
      ServerName: {{ pillar['koha']['instance'] }}

#########
# PLACK IN DOCKER SOCKET WORKAROUND
#########

/usr/share/perl5/Authen/CAS/Client/Response/Failure.pm:
  file.managed:
    - source: salt://koha/files/Authen_CAS_Client_Response_Failure.pm
    - makedirs: True

/usr/share/perl5/Authen/CAS/Client/Response/Success.pm:
  file.managed:
    - source: salt://koha/files/Authen_CAS_Client_Response_Success.pm
    - makedirs: True

#########
# END PLACK IN DOCKER SOCKET WORKAROUND
#########

apache2:
  service.running:
    - watch:
      - file: config_apacheinstance

koha-common:
  service.running:
    - watch:
      - file: config_zebrapass
