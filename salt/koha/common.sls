##########
# KOHA-COMMON
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

koha-common:
  pkg.installed:
    - skip_verify: True
    - version: 16.05.00+201606021043~patched
    - require:
      - pkgrepo: deichmanrepo
      - pkgrepo: koharepo
