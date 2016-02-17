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
# SIP_PORT      6001
# SIP_WORKERS   3
# SIP_AUTOUSER1 autouser
# SIP_AUTOPASS1 autopass
################################
# KOHA DEV ENVIRONMENT VARIABLES
################################
# AUTHOR_NAME  john_doe
# AUTHOR_EMAIL john@doe.com
# BUGZ_USER    bugsquasher
# BUGZ_PASS    bugspass
# KOHA_REPO    https://github.com/Koha-Community/Koha.git
# MY_REPO      https://github.com/digibib/koha-work
# GITBZ_REPO   https://github.com/digibib/git-bz.git
# QATOOLS_REPO https://github.com/Koha-Community/qa-test-tools.git
#######################

# Configure Git and some repos
echo "Configuring git ..."
git config --global user.name "$AUTHOR_NAME" && \
    git config --global user.email "$AUTHOR_EMAIL" && \
    git config --global color.status auto && \
    git config --global color.branch auto && \
    git config --global color.diff auto && \
    git config --global diff.tool vimdiff && \
    git config --global difftool.prompt false && \
    git config --global alias.d difftool && \
    git config --global alias.update '!sh -c "git checkout master && \
      (git branch -d newmaster 2>/dev/null || true) && \
      (git branch -d oldmaster 2>/dev/null || true) && \
      git fetch origin master:newmaster --depth=1 && \
      git branch -m master oldmaster && \
      git branch -m newmaster master && \
      git checkout master"' && \
    # Allows usage like git qa <bugnumber> to set up a branch based on master and fetch patches for <bugnumber> from bugzilla
    git config --global alias.qa '!sh -c "git fetch origin master --depth=1 && git rebase origin/master && git checkout -b qa-$1 origin/master && git bz apply $1"' - && \
    # Allows usage like git qa-tidy <bugnumber> to remove a qa branch when you are through with it
    git config --global alias.qa-tidy '!sh -c "git checkout master && git branch -D qa-$1"' - && \
    git config --global core.whitespace trailing-space,space-before-tab && \
    git config --global apply.whitespace fix

# Configure bugzilla login
echo "Configuring bugzilla..."
git config --global bz.default-tracker bugs.koha-community.org && \
    git config --global bz.default-product Koha && \
    git config --global bz-tracker.bugs.koha-community.org.path /bugzilla3 && \
    git config --global bz-tracker.bugs.koha-community.org.bz-user $BUGZ_USER && \
    git config --global bz-tracker.bugs.koha-community.org.bz-password $BUGZ_PASS

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

# SIP2 Server config
salt-call --local state.sls koha.sip2-dev \
  pillar="{koha: {instance: $KOHA_INSTANCE, sip_port: $SIP_PORT, \
  sip_workers: $SIP_WORKERS, sip_autouser1: $SIP_AUTOUSER1, sip_autopass1: $SIP_AUTOPASS1}}"

# Run webinstaller to autoupdate/validate install
salt-call --local state.sls koha.webinstaller \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

/etc/init.d/koha-common restart
/etc/init.d/apache2 restart
/etc/init.d/cron restart

/usr/bin/tail -f /var/log/apache2/access.log \
  /var/log/koha/${KOHA_INSTANCE}/intranet*.log \
  /var/log/koha/${KOHA_INSTANCE}/opac*.log \
  /var/log/koha/${KOHA_INSTANCE}/zebra*.log \
  /var/log/apache2/other_vhosts_access.log \
  /var/log/koha/${KOHA_INSTANCE}/sip*.log
