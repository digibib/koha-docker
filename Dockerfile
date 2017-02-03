#######
# Debian Jessie build of Koha
#######

FROM debian:jessie

MAINTAINER Oslo Public Library "digitalutvikling@gmail.com"

ENV REFRESHED_AT 2017-01-23

RUN echo "APT::Acquire::Retries \"3\";" > /etc/apt/apt.conf.d/80-retries
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get upgrade --yes && \
    apt-get install -y wget less curl git nmap socat netcat tree htop \ 
                       unzip python-software-properties libswitch-perl \
                       libnet-ssleay-perl libcrypt-ssleay-perl apache2 \
                       supervisor inetutils-syslogd && \
    apt-get clean

ARG KOHA_BUILD

ENV KOHA_ADMINUSER admin
ENV KOHA_ADMINPASS secret
ENV KOHA_INSTANCE  name
ENV KOHA_ZEBRAUSER zebrauser
ENV KOHA_ZEBRAPASS lkjasdpoiqrr

#######
# Mysql config for initial db
#######
RUN echo "mysql-server mysql-server/root_password password $KOHA_ADMINPASS" | debconf-set-selections && \
    echo "mysql-server mysql-server/root_password_again password $KOHA_ADMINPASS" | debconf-set-selections && \
    apt-get install -y mysql-server && \
    sed "/max_allowed_packet/c\*/max_allowed_packet = 64M" /etc/mysql/my.cnf && \
    sed "/wait_timeout/c\*/wait_timeout = 6000" /etc/mysql/my.cnf

########
# Files and templates
########

# Global files
COPY ./files/local-apt-repo /etc/apt/preferences.d/local-apt-repo

# Install Koha Common
RUN sed -i "s/httpredir.debian.org/`curl -s -D - http://httpredir.debian.org/demo/debian/ | \
    awk '/^Link:/ { print $2 }' | sed -e 's@<http://\(.*\)/debian/>;@\1@g'`/" /etc/apt/sources.list && \
    echo "search deich.folkebibl.no guest.oslo.kommune.no\nnameserver 10.172.2.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf && \
    echo "deb http://datatest.deichman.no/repositories/koha/public/ wheezy main" > /etc/apt/sources.list.d/deichman.list && \
    echo "deb http://debian.koha-community.org/koha stable main" > /etc/apt/sources.list.d/koha.list && \
    wget -q -O- http://debian.koha-community.org/koha/gpg.asc | apt-key add - && \
    apt-get update && apt-get install -y --force-yes koha-common=$KOHA_BUILD && apt-get clean


# Script and deps for checking if koha is up & ready (to be executed using docker exec)
COPY docker-wait_until_ready.py /root/wait_until_ready.py
RUN apt-get install -y python-requests && apt-get clean
# Missing perl dependencies
RUN apt-get install -y \
    libhtml-strip-perl libipc-run3-perl paps \
    libyaml-libyaml-perl && \
    apt-get clean

# Installer files
COPY ./files/installer /installer

# Templates
COPY ./files/templates /templates

# Cronjobs
COPY ./files/cronjobs /cronjobs

# Apache settings
RUN echo "\nListen 8080\nListen 8081" | tee /etc/apache2/ports.conf && \
    a2dissite 000-default && \
    a2enmod rewrite headers proxy_http cgi remoteip

# LinkMobiblity SMS Driver - SMS modules need to be in shared perl libs
RUN mkdir -p /usr/share/perl5/SMS/Send/NO && \
  cp /usr/share/koha/intranet/cgi-bin/sms/LinkMobilityHTTP.pm /usr/share/perl5/SMS/Send/NO/LinkMobilityHTTP.pm

# Template for batch print notices
RUN cp /templates/global/print-notices-deichman.tt /usr/share/koha/intranet/htdocs/intranet-tmpl/prog/en/modules/batch/

# Koha SIP2 server
ENV SIP_PORT      6001
ENV SIP_WORKERS   3

# Set local timezone
RUN echo "Europe/Oslo" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata

#############
# WORKAROUNDS
#############

# CAS bug workaround
ADD ./files/Authen_CAS_Client_Response_Failure.pm /usr/share/perl5/Authen/CAS/Client/Response/Failure.pm
ADD ./files/Authen_CAS_Client_Response_Success.pm /usr/share/perl5/Authen/CAS/Client/Response/Success.pm

ENV HOME /root
WORKDIR /root

#############
# LOGGING AND CRON
#############

COPY ./files/logrotate.config /etc/logrotate.d/syslog.conf
COPY ./files/syslog.config /etc/syslog.conf

# Cronjob for sending print notices to print service
COPY ./files/cronjobs/brevdue.pl /usr/share/koha/bin/cronjobs/brevdue.pl
RUN chmod 0755 /usr/share/koha/bin/cronjobs/brevdue.pl

# Override nightly and hourly run koha cron jobs
COPY ./files/cronjobs/daily-koha-common /etc/cron.daily/koha-common
RUN chmod 0755 /etc/cron.daily/koha-common && rm -rf /etc/cron.hourly/koha-common

COPY docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]

EXPOSE 6001 8080 8081
