##########
# KOHA CREATE VANILLA INSTANCE WITH DEFAULT SCHEMAS
# Replicates web installer steps 1-3
##########

koha_common_cnf:
  file.managed:
    - name: /etc/mysql/koha-common.cnf
    - source: salt://koha/files/koha-common.cnf
    - template: jinja

# Request DB creation on remote db
requestkohadb:
  cmd.run:
    - name: koha-create --request-db {{ pillar['koha']['instance'] }} || true

# Populate remote db
populatekohadb:
  cmd.run:
    #- unless: id -u {{ pillar['koha']['instance'] }}-koha >/dev/null 2>&1
    - name: koha-create --populate-db {{ pillar['koha']['instance'] }}
