##########
# KOHA RESTFUL API
##########

libcgi-application-dispatch-perl:
  pkg.installed

restful-git:
  git.latest:
    - name: https://github.com/digibib/koha-restful.git
    - rev: master
    - target: /usr/local/src/koha-restful

# PROD
/usr/share/koha/lib/Koha/REST:
  file.symlink:
    - target: /usr/local/src/koha-restful/Koha/REST

/usr/share/koha/opac/cgi-bin/opac/rest.pl:
  file.symlink:
    - target: /usr/local/src/koha-restful/opac/rest.pl

/etc/koha/sites/{{ pillar['koha']['instance'] }}/rest:
  file.directory:
    - user: {{ pillar['koha']['instance'] }}-koha
    - group: {{ pillar['koha']['instance'] }}-koha
    - mode: 755
    - makedirs: True

/etc/koha/sites/{{ pillar['koha']['instance'] }}/rest/config.yaml:
  file.managed:
    - source: {{ pillar['koha']['saltfiles'] }}/koha-restful-config.yaml
    - user: {{ pillar['koha']['instance'] }}-koha
    - group: {{ pillar['koha']['instance'] }}-koha    
    - require:
      - file: /etc/koha/sites/{{ pillar['koha']['instance'] }}/rest
