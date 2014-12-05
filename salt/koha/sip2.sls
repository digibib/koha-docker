########
# KOHA SIP2 SERVER
########

/etc/koha/sites/{{ pillar['koha']['instance'] }}/SIPconfig.xml:
  file.managed:
    - source: salt://koha/files/SIPconfig.xml
    - user: {{ pillar['koha']['instance'] }}-koha
    - mode: 640
    - template: jinja
    - context:
      sip_workers: {{ pillar['koha']['sip_workers'] }}
      sip_port: {{ pillar['koha']['sip_port'] }}
      autouser1: {{ pillar['koha']['sip_autouser1'] }}
      autopass1: {{ pillar['koha']['sip_autopass1'] }}

start_sip_server:
  cmd.run:
    - name: /usr/sbin/koha-start-sip {{ pillar['koha']['instance'] }}
