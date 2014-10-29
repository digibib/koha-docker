#!/bin/bash
set -e

########
# Container config variables - defaults from Dockerfile:
# KOHA_INSTANCE  name
# KOHA_ADMINUSER admin
# KOHA_ADMINPASS secret
# KOHA_ZEBRAUSER zebrauser
# KOHA_ZEBRAPASS lkjasdpoiqrr
########

# Apache config
salt-call --local state.sls koha.apache2 pillar="{koha: {instance: $KOHA_INSTANCE}}"

# Sites global config
salt-call --local state.sls koha.sites-config \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

# If not linked to an existing mysql container, use local mysql server
if [[ -z "$DB_PORT" ]] ; then
  /etc/init.d/mysql start
  echo "127.0.0.1  db" >> /etc/hosts
  echo "CREATE USER '$KOHA_ADMINUSER'@'%' IDENTIFIED BY '$KOHA_ADMINPASS' ;
        CREATE DATABASE IF NOT EXISTS koha_$KOHA_INSTANCE ; \
        CREATE DATABASE IF NOT EXISTS koha_restful_test ; \
        GRANT ALL ON koha_$KOHA_INSTANCE.* TO '$KOHA_ADMINUSER'@'%' WITH GRANT OPTION ; \
        GRANT ALL ON koha_restful_test.* TO '$KOHA_ADMINUSER'@'%' WITH GRANT OPTION ; \
        FLUSH PRIVILEGES ;" | mysql -u root
fi

# Request and populate DB
salt-call --local state.sls koha.createdb \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

# Local instance config
salt-call --local state.sls koha.config \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS, \
  zebrauser: $KOHA_ZEBRAUSER, zebrapass: $KOHA_ZEBRAPASS}}"

# Run webinstaller to autoupdate/validate install
salt-call --local state.sls koha.webinstaller \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

/etc/init.d/koha-common start
/etc/init.d/apache2 start
/etc/init.d/cron start
/etc/init.d/logstash-forwarder start

exec "$@"