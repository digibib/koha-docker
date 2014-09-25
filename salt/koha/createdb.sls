##########
# KOHA CREATE VANILLA INSTANCE WITH DEFAULT SCHEMAS
# Replicates web installer steps 1-3
##########

mysql-running:
  cmd.run:
    - name: nohup mysqld & echo $! > pid.txt ; exit 0

# Create instance user and empty database if not already existant
createkohadb:
  cmd.run:
    - unless: id -u {{ pillar['koha']['instance'] }}-koha >/dev/null 2>&1
    - name: koha-create --create-db {{ pillar['koha']['instance'] }}

mysql-dead:
  service.dead:
  - name: mysql
