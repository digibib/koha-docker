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
#######################
# SIP2 DEFAULT SETTINGS
#######################
# SIP_HOST      0.0.0.0
# SIP_PORT      6001
# SIP_WORKERS   3
# SIP_AUTOUSER1 autouser
# SIP_AUTOPASS1 autopass
########################
# KOHA LANGUAGE SETTINGS
########################
# DEFAULT_LANGUAGE
# INSTALL_LANGUAGES
########################
# EMAIL_ENABLED    false
# SMTP_SERVER_HOST localhost
# SMTP_SERVER_PORT 25
# MESSAGE_QUEUE_FREQUENCY 15
########################
# SMS_ENABLED      false
# SMS_FORWARD_URL  http://localhost:8101
########################

# Apache Koha instance config
salt-call --local state.sls koha.apache2 pillar="{koha: {instance: $KOHA_INSTANCE}}"

# Koha Sites global config
salt-call --local state.sls koha.sites-config \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

# If not linked to an existing mysql container, use local mysql server
if [[ -z "$DB_PORT" ]] ; then
  /etc/init.d/mysql start
  echo "127.0.0.1  koha_mysql" >> /etc/hosts
  echo "CREATE USER '$KOHA_ADMINUSER'@'%' IDENTIFIED BY '$KOHA_ADMINPASS' ;
        CREATE DATABASE IF NOT EXISTS koha_$KOHA_INSTANCE ; \
        GRANT ALL ON koha_$KOHA_INSTANCE.* TO '$KOHA_ADMINUSER'@'%' WITH GRANT OPTION ; \
        FLUSH PRIVILEGES ;" | mysql -u root
fi

# Request and populate DB
salt-call --local state.sls koha.createdb \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

# Local instance config
salt-call --local state.sls koha.config \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS, \
  zebrauser: $KOHA_ZEBRAUSER, zebrapass: $KOHA_ZEBRAPASS}}"

# Install languages in Koha
for language in $INSTALL_LANGUAGES
do
    koha-translate --install $language
done

# Run webinstaller to autoupdate/validate install
salt-call --local state.sls koha.webinstaller \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

# Install the default language if not already installed
if [ -n "$DEFAULT_LANGUAGE" ]; then
    if [ -z `koha-translate --list | grep -Fx $DEFAULT_LANGUAGE` ] ; then
        koha-translate --install $DEFAULT_LANGUAGE
    fi

    echo -n "UPDATE systempreferences SET value = '$DEFAULT_LANGUAGE' WHERE variable = 'language';
        UPDATE systempreferences SET value = '$DEFAULT_LANGUAGE' WHERE variable = 'opaclanguages';" | \
        koha-mysql $KOHA_INSTANCE
fi

# MESSAGING SETTINGS
if [ -n "$MESSAGE_QUEUE_FREQUENCY" ]; then
  sed -i "/process_message_queue/c\*/${MESSAGE_QUEUE_FREQUENCY} * * * * root koha-foreach --enabled --email \
  /usr/share/koha/bin/cronjobs/process_message_queue.pl" /etc/cron.d/koha-common
fi

if [ -n "$EMAIL_ENABLED" ]; then
  # Koha uses default sendmail localhost, so need to override perl Sendmail config
  if [ -n "$SMTP_SERVER_HOST" ]; then
    sub="%mailcfg = (
      'smtp'    => [ '$SMTP_SERVER_HOST' ],
      'from'    => '', # default sender e-mail, used when no From header in mail
      'mime'    => 1, # use MIME encoding by default
      'retries' => 1, # number of retries on smtp connect failure
      'delay'   => 1, # delay in seconds between retries
      'tz'      => '', # only to override automatic detection
      'port'    => $SMTP_SERVER_PORT,
      'debug'   => 0,
    );"
    sendmail=/usr/share/perl5/Mail/Sendmail.pm
    awk -v sb="$sub" '/^%mailcfg/,/;/ { if ( $0 ~ /\);/ ) print sb; next } 1' $sendmail > tmp && \
      mv tmp $sendmail
  fi
  koha-email-enable $KOHA_INSTANCE
fi

if [ -n "$SMS_ENABLED" ]; then
  if [ -n "$SMS_FORWARD_URL" ]; then
    # SMS modules need to go to shared perl libs
    mkdir -p /usr/share/perl5/SMS/Send/NO
    sed -e "s/__REPLACE_WITH_SMS_URL__/${SMS_FORWARD_URL}/g" /usr/share/koha/Koha/lib/SMS_HTTP.pm > /usr/share/perl5/SMS/Send/NO/SMS_HTTP.pm
  fi
fi

# SIP2 Server config
salt-call --local state.sls koha.sip2 \
  pillar="{koha: {instance: $KOHA_INSTANCE, sip_port: $SIP_PORT, \
  sip_workers: $SIP_WORKERS, sip_autouser1: $SIP_AUTOUSER1, sip_autopass1: $SIP_AUTOPASS1}}"

/etc/init.d/cron start

# Enable plack
koha-plack --enable "$KOHA_INSTANCE"
koha-plack --start "$KOHA_INSTANCE"
service apache2 restart

# Make sure log files exist before tailing them
touch /var/log/koha/${KOHA_INSTANCE}/intranet-error.log; chmod ugo+rw /var/log/koha/${KOHA_INSTANCE}/intranet-error.log
touch /var/log/koha/${KOHA_INSTANCE}/sip-error.log; chmod ugo+rw /var/log/koha/${KOHA_INSTANCE}/sip-error.log
touch /var/log/koha/${KOHA_INSTANCE}/sip-output.log; chmod ugo+rw /var/log/koha/${KOHA_INSTANCE}/sip-output.log
touch /var/log/koha/${KOHA_INSTANCE}/sip-output.log; chmod ugo+rw /var/log/koha/${KOHA_INSTANCE}/plack-error.log

/usr/bin/tail -f /var/log/apache2/access.log \
  /var/log/koha/${KOHA_INSTANCE}/intranet*.log \
  /var/log/koha/${KOHA_INSTANCE}/opac*.log \
  /var/log/koha/${KOHA_INSTANCE}/zebra*.log \
  /var/log/apache2/other_vhosts_access.log \
  /var/log/koha/${KOHA_INSTANCE}/sip*.log \
  /var/log/koha/${KOHA_INSTANCE}/plack*.log
