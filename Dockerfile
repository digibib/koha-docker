#######
# Debian Jessie build of Koha - Provisioned by Salt
#######

FROM debian:jessie

MAINTAINER Oslo Public Library "digitalutvikling@gmail.com"

ENV REFRESHED_AT 2015-01-06

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get upgrade --yes && \
    apt-get install -y wget less curl git nmap socat netcat tree htop \ 
                       unzip python-software-properties libswitch-perl && \
    apt-get clean

ENV KOHA_ADMINUSER admin
ENV KOHA_ADMINPASS secret
ENV KOHA_INSTANCE  name
ENV KOHA_ZEBRAUSER zebrauser
ENV KOHA_ZEBRAPASS lkjasdpoiqrr
ENV KOHA_DBHOST    koha_mysql
ENV SALT_VERSION 2015.5.2

#######
# Salt Install
#######

# Salt dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y python-m2crypto python-yaml python-jinja2 python-requests python-markupsafe \
      msgpack-python python-zmq && \
    apt-get clean

# Install salt
RUN curl -O https://pypi.python.org/packages/source/s/salt/salt-${SALT_VERSION}.tar.gz && \
  tar -xzvf salt-${SALT_VERSION}.tar.gz && \
  cd salt-${SALT_VERSION} && \
  python setup.py install && \
  rm -rf salt-${SALT_VERSION}

#######
# Salt Configuration
#######

# enable salt grains cache for speed improvement
RUN mkdir -p /etc/salt && \
  echo "grains_cache: True" >> /etc/salt/minion

#######
# Salt Provisioning
# Package installs
#######

ADD ./pillar /srv/pillar/
COPY ./pillar/koha/admin.sls.example /srv/pillar/koha/admin.sls

ADD ./salt/common/init.sls /srv/salt/common/init.sls
RUN salt-call --local --retcode-passthrough state.sls common

ADD ./salt/koha/init.sls /srv/salt/koha/init.sls 
RUN salt-call --local --retcode-passthrough state.sls koha

# Need mysql server to create initial db
ADD ./salt/mysql/server.sls /srv/salt/mysql/server.sls
RUN salt-call --local --retcode-passthrough state.sls mysql.server

# Koha common settings
ADD ./salt/koha/common.sls /srv/salt/koha/common.sls
ADD ./salt/koha/files/koha-common.cnf /srv/salt/koha/files/koha-common.cnf
ADD ./salt/koha/files/koha-conf.xml.tmpl /srv/salt/koha/files/koha-conf.xml.tmpl
ADD ./salt/koha/files/zebra.passwd.tmpl /srv/salt/koha/files/zebra.passwd.tmpl
ADD ./salt/koha/files/local-apt-repo.tmpl /srv/salt/koha/files/local-apt-repo.tmpl
RUN salt-call --local --retcode-passthrough state.sls koha.common

#######
# Salt Provisioning - step 2
# Configuration files
#######

# Apache settings
ADD ./salt/koha/apache2.sls /srv/salt/koha/apache2.sls
ADD ./salt/koha/files/apache.tmpl /srv/salt/koha/files/apache.tmpl
ADD ./salt/koha/files/log4perl.conf /srv/salt/koha/files/log4perl.conf

# Koha instance settings
ADD ./salt/koha/sites-config.sls /srv/salt/koha/sites-config.sls
ADD ./salt/koha/files/koha-sites.conf /srv/salt/koha/files/koha-sites.conf
ADD ./salt/koha/files/passwd /srv/salt/koha/files/passwd

# Koha DB settings, and post-config
ADD ./salt/koha/files/SIPconfig.xml /srv/salt/koha/files/SIPconfig.xml
ADD ./salt/koha/sip2.sls /srv/salt/koha/sip2.sls

# Koha SIP2 server
ENV SIP_PORT      6001
ENV SIP_WORKERS   3
ENV SIP_AUTOUSER1 autouser
ENV SIP_AUTOPASS1 autopass

ADD ./salt/koha/createdb.sls /srv/salt/koha/createdb.sls
ADD ./salt/koha/config.sls /srv/salt/koha/config.sls

# Koha automated webinstaller
ADD ./salt/koha/webinstaller.sls /srv/salt/koha/webinstaller.sls
ADD ./salt/koha/files/KohaWebInstallAutomation.pl /srv/salt/koha/files/KohaWebInstallAutomation.pl
ADD ./salt/koha/files/updatekohadbversion.sh /srv/salt/koha/files/updatekohadbversion.sh
ADD ./salt/koha/webinstaller.sls /srv/salt/koha/webinstaller.sls

# CAS bug workaround
ADD ./salt/koha/files/Authen_CAS_Client_Response_Failure.pm /srv/salt/koha/files/Authen_CAS_Client_Response_Failure.pm
ADD ./salt/koha/files/Authen_CAS_Client_Response_Success.pm /srv/salt/koha/files/Authen_CAS_Client_Response_Success.pm

# Activate Plack and REST API

# Add mojolicious and swagger2 deps that are not yet in kohadeps
RUN apt-get install -y make cpanminus && \
    cpanm Mojolicious@6.0 Swagger2@0.59 && \
    apt-get purge -y cpanminus make && apt-get clean
# Remove them when in stable deb repos

ADD ./salt/koha/files/plack.psgi /srv/salt/koha/files/plack.psgi
ADD ./salt/koha/files/apache-shared-intranet-plack.conf.tmpl /srv/salt/koha/files/apache-shared-intranet-plack.conf.tmpl

# For now we use api definitions from Koha
#ADD ./salt/koha/files/api /srv/salt/koha/files/api

ENV HOME /root
WORKDIR /root

COPY docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]

EXPOSE 6001 8080 8081

# Script for checking if koha is up & ready (to be executed using docker exec)
COPY docker-wait_until_ready.py /root/wait_until_ready.py
