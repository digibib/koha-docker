#!/bin/bash
set -e

if [ -z $KOHA_ADMINUSER ]; then
  echo >&2 'error: $KOHA_ADMINUSER not set'
  echo >&2 '  Did you forget to add -e KOHA_ADMINUSER=... ?'
  exit 1
fi

salt-call --local state.sls koha.apache2 pillar="{koha: {instance: $KOHA_INSTANCE}}"
salt-call --local state.sls koha.sites-config \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"
# Mysql dummy - because koha expects local db in initial setup...
#/etc/init.d/mysql start
salt-call --local state.sls koha.createdb pillar="{koha: {instance: $KOHA_INSTANCE}}"
#/etc/init.d/mysql stop 

salt-call --local state.sls koha.config \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS, \
  zebrauser: $KOHA_ZEBRAUSER, zebrapass: $KOHA_ZEBRAPASS}}"

salt-call --local state.sls koha.restful pillar="{koha: {instance: $KOHA_INSTANCE}}"
salt-call --local state.sls koha.webinstaller \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

  
exec "$@"