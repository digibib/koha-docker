##########
# KOHA-COMMON-LOCAL-DEBS
##########

local-apt-repo-priority:
  file.managed:
    - name: /etc/apt/preferences.d/local-apt-repo
    - source: salt://koha/files/local-apt-repo.tmpl

deichmanrepo:
  pkgrepo.managed:
    - name: deb http://datatest.deichman.no/repositories/koha/public/ wheezy main
    - watch:
      - file: local-apt-repo-priority

koharepo:
  pkgrepo.managed:
    - name: deb http://debian.koha-community.org/koha stable main
    - key_url: http://debian.koha-community.org/koha/gpg.asc

{% set version = '3.23.00+201605051020~patched' %}

/tmp/koha-perldeps_{{ version }}_all.deb:
  file.managed:
    - source: salt://debian/koha-perldeps_{{ version }}_all.deb
  cmd.run:
    - name: dpkg -i /tmp/koha-perldeps_{{ version }}_all.deb || apt-get install -y -f

/tmp/koha-deps_{{ version }}_all.deb:
  file.managed:
    - source: salt://debian/koha-deps_{{ version }}_all.deb
  cmd.run:
    - name: dpkg -i /tmp/koha-deps_{{ version }}_all.deb || apt-get install -y -f

/tmp/koha-common_{{ version }}_all.deb:
  file.managed:
    - source: salt://debian/koha-common_{{ version }}_all.deb
  cmd.run:
    - name: dpkg -i /tmp/koha-common_{{ version }}_all.deb || apt-get install -y -f
