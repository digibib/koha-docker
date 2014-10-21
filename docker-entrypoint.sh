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

# Request and populate DB
salt-call --local state.sls koha.createdb \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

# Local instance config
salt-call --local state.sls koha.config \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS, \
  zebrauser: $KOHA_ZEBRAUSER, zebrapass: $KOHA_ZEBRAPASS}}"

# Koha-restful connfig
salt-call --local state.sls koha.restful-config pillar="{koha: {instance: $KOHA_INSTANCE}}"

# Run webinstaller to autoupdate/validate install
salt-call --local state.sls koha.webinstaller \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

/etc/init.d/koha-common start
/etc/init.d/apache2 start
/etc/init.d/cron start

exec "$@"