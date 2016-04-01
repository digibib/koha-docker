#######
# DEVELOPMENT IMAGE OF KOHA - PROVISIONED BY SALT
# Baser on debian wheezy vanilla Koha
#######

FROM digibib/koha:8e0ff03040bb328305b572c68668c11dea2dc197

MAINTAINER Oslo Public Library "digitalutvikling@gmail.com"

ENV REFRESHED_AT 2015-12-09

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    sudo apt-get install -q -y cpanminus vim git-email telnet screen wget less curl htop && \
    apt-get clean

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

RUN mkdir -p /kohadev && cd /kohadev && \
    git clone --depth=1 $KOHA_REPO kohaclone

# kohadev dependencies
RUN apt-get install -y libtemplate-plugin-json-escape-perl libtext-bidi-perl \
    libdbix-connector-perl make libtest-warnings-perl && \
    apt-get clean

# Git bz
# http://wiki.koha-community.org/wiki/Git_bz_configuration
RUN cd /kohadev && \
    git clone $GITBZ_REPO gitbz && \
    cd gitbz && git checkout -b fishsoup origin/fishsoup && \
    sudo ln -s /kohadev/gitbz/git-bz /usr/local/bin/git-bz

# Apache dev settings
ADD apache-kohadev.conf /srv/salt/koha/files/apache.tmpl
ADD koha-conf.xml.tmpl /srv/salt/koha/files/koha-conf.xml.tmpl

# Use SIP2 Development version from git
ADD sip2-dev.sls /srv/salt/koha/sip2-dev.sls
ADD sip2-dev-stop.sls /srv/salt/koha/sip2-dev-stop.sls

ENV HOME /root
WORKDIR /root

COPY docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]

EXPOSE 6001 8080 8081

VOLUME ["/kohadev"]

# Script for checking if koha is up & ready (to be executed using docker exec)
COPY docker-wait_until_ready.py /root/wait_until_ready.py