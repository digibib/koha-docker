#!/bin/bash
set -e

#######################
# INSTANCE DEFAULTS
#######################
# KOHA_INSTANCE  name
# KOHA_ADMINUSER admin
# KOHA_ADMINPASS secret
# KOHA_ZEBRAUSER zebrauser
# KOHA_ZEBRAPASS lkjasdpoiqrr
# KOHA_PLACK_PORT 5000
#######################
# SIP2 DEFAULT SETTINGS
#######################
# SIP_HOST      0.0.0.0
# SIP_PORT      6001
# SIP_WORKERS   3
# SIP_AUTOUSER1 autouser
# SIP_AUTOPASS1 autopass
########################

# Apache Koha instance config
salt-call --local state.sls koha.apache2 pillar="{koha: {instance: $KOHA_INSTANCE}}"

# Koha Sites global config
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

# SIP2 Server config
salt-call --local state.sls koha.sip2 \
  pillar="{koha: {instance: $KOHA_INSTANCE, sip_port: $SIP_PORT, \
  sip_workers: $SIP_WORKERS, sip_autouser1: $SIP_AUTOUSER1, sip_autopass1: $SIP_AUTOPASS1}}"

/etc/init.d/cron start

KOHA_CONF=/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml PERL5LIB=/srv/koha sudo -E -u ${KOHA_INSTANCE}-koha \
  plackup --D --access-log /var/log/koha/${KOHA_INSTANCE}/intranet_plack.log --reload --port ${KOHA_PLACK_PORT} /usr/share/koha/intranet/intra.psgi

/usr/bin/tail -f /var/log/apache2/access.log \
  /var/log/koha/${KOHA_INSTANCE}/intranet*.log \
  /var/log/koha/${KOHA_INSTANCE}/intranet_plack*.log \
  /var/log/koha/${KOHA_INSTANCE}/opac*.log \
  /var/log/koha/${KOHA_INSTANCE}/zebra*.log \
  /var/log/apache2/other_vhosts_access.log \
  /var/log/koha/${KOHA_INSTANCE}/sip*.log
