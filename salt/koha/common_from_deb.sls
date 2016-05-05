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

{% set version = '3.23.00+201605050831~patched' %}
#koha-local-perldeps:
#  pkg.installed:
#    - skip_verify: True
#    - skip_suggestions: True
#    - sources:
#      - koha_perldeps: salt://debian/koha-perldeps_{{ version }}_all.deb


# koha-local-deps:
#   pkg.installed:
#     - skip_verify: True
#     - sources:
#       - koha_deps: salt://debian/koha-deps_{{ version }}_all.deb
#     - require:
#       - pkg: koha-local-perldeps

# koha-local-common:
#   pkg.installed:
#     - skip_verify: True
#     - sources:
#       - koha_common: salt://debian/koha-common_{{ version }}_all.deb
#     - require:
#       - pkg: koha-local-deps

#- koha: salt://debian/koha_{{ version }}_all.deb



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
