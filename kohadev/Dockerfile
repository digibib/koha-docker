#######
# DEVELOPMENT IMAGE OF KOHA
# Based on debian jessy Koha 
# USES a docker image built from GITREF from koha-salt-docker 
#######

FROM digibib/koha:67c38f6aa0d05980c20dc09199df18eef9e317c9

MAINTAINER Oslo Public Library "digitalutvikling@gmail.com"

ENV REFRESHED_AT 2016-06-20

#########################
# KOHA INSTANCE VARIABLES
#########################

ENV KOHA_ADMINUSER admin
ENV KOHA_ADMINPASS secret
ENV KOHA_INSTANCE name
ENV KOHA_ZEBRAUSER zebrauser
ENV KOHA_ZEBRAPASS lkjasdpoiqrr

################################
# KOHA DEV ENVIRONMENT VARIABLES
################################

ENV AUTHOR_NAME  john_doe
ENV AUTHOR_EMAIL john@doe.com
ENV BUGZ_USER    bugsquasher
ENV BUGZ_PASS    bugspass
ENV KOHA_REPO    https://github.com/Koha-Community/Koha.git
ENV MY_REPO      https://github.com/digibib/koha-work
ENV GITBZ_REPO   https://github.com/digibib/git-bz.git
ENV QATOOLS_REPO https://github.com/Koha-Community/qa-test-tools.git

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    sudo apt-get install -q -y cpanminus vim git-email telnet screen wget less curl htop && \
    apt-get clean

RUN mkdir -p /kohadev && cd /kohadev && \
    git clone --depth=1 $KOHA_REPO kohaclone

# kohadev dependencies
RUN apt-get install -y libtemplate-plugin-json-escape-perl libtext-bidi-perl libwww-csrf-perl \
    libdbix-connector-perl make libtest-warnings-perl libplack-middleware-debug-perl && \
    apt-get clean

# Git bz
# http://wiki.koha-community.org/wiki/Git_bz_configuration
RUN cd /kohadev && \
    git clone $GITBZ_REPO gitbz && \
    cd gitbz && git checkout -b fishsoup origin/fishsoup && \
    ln -s /kohadev/gitbz/git-bz /usr/local/bin/git-bz

# Global dev settings
ADD koha-common.tmpl /etc/default/koha-common
ADD apache-shared-intranet-plack.conf.tmpl /etc/koha/apache-shared-intranet-plack.conf
ADD plack.psgi /etc/koha/plack.psgi

# Override with kohadev templates
ADD koha-conf.xml.tmpl /templates/instance/koha.conf.xml.tmpl
ADD apache.tmpl /templates/instance/apache.tmpl

# Use SIP2 Development version from git
#ADD sip2-dev.sls /srv/salt/koha/sip2-dev.sls
#ADD sip2-dev-stop.sls /srv/salt/koha/sip2-dev-stop.sls

ENV HOME /root
WORKDIR /root

COPY docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]

EXPOSE 6001 8080 8081

VOLUME ["/kohadev"]

# Script and deps for checking if koha is up & ready (to be executed using docker exec)
RUN apt-get install -y python-requests && apt-get clean
COPY docker-wait_until_ready.py /root/wait_until_ready.py
