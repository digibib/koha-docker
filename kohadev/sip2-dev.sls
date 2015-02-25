########
# KOHA SIP2 SERVER DEVELOPMENT VERSION
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

start_devSIP:
  cmd.run:
    - cwd: /kohadev/kohaclone
    - name: screen -dmS kohadev-sip sh -c 'cd /kohadev/kohaclone ; KOHA_CONF=/etc/koha/sites/{{ pillar['koha']['instance'] }}/koha-conf.xml perl -IC4/SIP -MILS C4/SIP/SIPServer.pm /etc/koha/sites/{{ pillar['koha']['instance'] }}/SIPconfig.xml ; exec bash'
