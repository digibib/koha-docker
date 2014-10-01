##########
# KOHA RESTFUL INSTANCE CONFIG
##########

/etc/koha/sites/{{ pillar['koha']['instance'] }}/rest:
  file.directory:
    - user: {{ pillar['koha']['instance'] }}-koha
    - group: {{ pillar['koha']['instance'] }}-koha
    - mode: 755
    - makedirs: True

/etc/koha/sites/{{ pillar['koha']['instance'] }}/rest/config.yaml:
  file.managed:
    - source: salt://koha/files/koha-restful-config.yaml
    - user: {{ pillar['koha']['instance'] }}-koha
    - group: {{ pillar['koha']['instance'] }}-koha    
    - require:
      - file: /etc/koha/sites/{{ pillar['koha']['instance'] }}/rest
