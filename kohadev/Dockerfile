#######
# DEVELOPMENT IMAGE OF KOHA
# Based on debian jessy Koha
# USES a docker image built from GITREF from koha-salt-docker
#######

FROM digibib/koha:cf3164d8ccce3cdb4a078b9b70160ce30cb9c5b2

MAINTAINER Oslo Public Library "digitalutvikling@gmail.com"

ENV REFRESHED_AT 2018-01-23

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
ENV GITBZ_REPO   https://github.com/digibib/git-bz.git
ENV QATOOLS_REPO https://github.com/Koha-Community/qa-test-tools.git

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    sudo apt-get install -q -y cpanminus vim net-tools git-email telnet screen wget less curl htop && \
    apt-get clean

RUN mkdir -p /kohadev && cd /kohadev && \
    git clone --depth=1 $KOHA_REPO kohaclone

# kohadev dependencies
RUN apt-get install -y libtemplate-plugin-json-escape-perl libtext-bidi-perl libwww-csrf-perl \
    libdancer-perl libobject-tiny-perl libxml-libxml-simple-perl libconfig-merge-perl libnet-cups-perl \
    libdbix-connector-perl make libtest-warnings-perl libplack-middleware-debug-perl \
    libsereal-encoder-perl libsereal-decoder-perl libmojolicious-plugin-openapi-perl && \
    apt-get clean

# Git bz
# http://wiki.koha-community.org/wiki/Git_bz_configuration
RUN cd /kohadev && \
    git clone $GITBZ_REPO gitbz && \
    cd gitbz && git checkout -b fishsoup origin/fishsoup && \
    ln -s /kohadev/gitbz/git-bz /usr/local/bin/git-bz

# Global dev settings
ADD koha-common.tmpl /etc/default/koha-common
ADD plack.psgi /etc/koha/plack.psgi

# Override with kohadev templates
ADD supervisord.conf.tmpl /templates/global/supervisord.conf.tmpl
ADD koha-conf.xml.tmpl /templates/instance/koha-conf.xml.tmpl
ADD apache.tmpl /templates/instance/apache.tmpl

ENV HOME /root
WORKDIR /root

COPY docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]

EXPOSE 6001 8080 8081

VOLUME ["/kohadev"]

# Script and deps for checking if koha is up & ready (to be executed using docker exec)
RUN apt-get install -y python-requests && apt-get clean
COPY docker-wait_until_ready.py /root/wait_until_ready.py

RUN ln -s /kohadev/kohadocker/files/NCIPServer/ / || true
