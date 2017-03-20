#!/bin/bash
set -e

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
    git config --global core.editor vim && \
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
    git config --global bz-tracker.bugs.koha-community.org.https true && \
    git config --global core.whitespace trailing-space,space-before-tab && \
    git config --global apply.whitespace fix

echo "Koha Sites global config ..."
envsubst < /templates/global/koha-sites.conf.tmpl > /etc/koha/koha-sites.conf
envsubst < /templates/global/passwd.tmpl > /etc/koha/passwd

echo "Setting up supervisord ..."
envsubst < /templates/global/supervisord.conf.tmpl > /etc/supervisor/conf.d/supervisord.conf

echo "Mysql server setup ..."
if ping -c 1 -W 1 $KOHA_DBHOST ; then
  printf "Using linked mysql container $KOHA_DBHOST\n"
else
  printf "Unable to connect to linked mysql container $KOHA_DBHOST\n-- initializing local mysql ...\n"
  /etc/init.d/mysql start
  sleep 1 # waiting for mysql to spin up on slow computers
  echo "127.0.0.1  $KOHA_DBHOST" >> /etc/hosts
  echo "CREATE USER '$KOHA_ADMINUSER'@'%' IDENTIFIED BY '$KOHA_ADMINPASS' ; \
        CREATE USER '$KOHA_ADMINUSER'@'$KOHA_DBHOST' IDENTIFIED BY '$KOHA_ADMINPASS' ; \
        CREATE DATABASE IF NOT EXISTS koha_$KOHA_INSTANCE ; \
        GRANT ALL ON koha_$KOHA_INSTANCE.* TO '$KOHA_ADMINUSER'@'%' WITH GRANT OPTION ; \
        GRANT ALL ON koha_$KOHA_INSTANCE.* TO '$KOHA_ADMINUSER'@'$KOHA_DBHOST' WITH GRANT OPTION ; \
        FLUSH PRIVILEGES ;" | mysql -u root -p$KOHA_ADMINPASS
fi

echo "Initializing local instance ..."
envsubst < /templates/instance/koha-common.cnf.tmpl > /etc/mysql/koha-common.cnf
koha-create --request-db $KOHA_INSTANCE || true
koha-create --populate-db $KOHA_INSTANCE

echo "Configuring local instance ..."
envsubst < /templates/instance/koha-conf.xml.tmpl > /etc/koha/sites/$KOHA_INSTANCE/koha-conf.xml
envsubst < /templates/instance/log4perl.conf.tmpl > /etc/koha/sites/$KOHA_INSTANCE/log4perl.conf
envsubst < /templates/instance/zebra.passwd.tmpl > /etc/koha/sites/$KOHA_INSTANCE/zebra.passwd

envsubst < /templates/instance/apache.tmpl > /etc/apache2/sites-available/$KOHA_INSTANCE.conf
envsubst < /templates/instance/SIPconfig.xml.tmpl > /etc/koha/sites/$KOHA_INSTANCE/SIPconfig.xml

echo "Configuring languages ..."
# Install languages in Koha
for language in $INSTALL_LANGUAGES
do
    koha-translate --install $language
done

echo "Restarting apache to activate local changes..."
service apache2 restart

sleep 1 # waiting for apache restart to finish
echo "Running webinstaller and applying local deichman mods - please be patient ..."
cd /usr/share/koha/lib && /installer/installer.sh

echo "Enabling plack ..."
koha-plack --enable "$KOHA_INSTANCE"

echo "Installation finished - Stopping all services and giving supervisord control ..."
service apache2 stop
koha-indexer --stop "$KOHA_INSTANCE" || true
koha-stop-zebra "$KOHA_INSTANCE" || true

supervisord -c /etc/supervisor/conf.d/supervisord.conf
