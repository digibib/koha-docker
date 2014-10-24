#######
# Debian Wheezy build of Koha - Provisioned by Salt
#######

FROM debian:wheezy

MAINTAINER Oslo Public Library "digitalutvikling@gmail.com"

ENV REFRESHED_AT 2014-10-20

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y wget less curl git nmap socat netcat tree htop \ 
                       unzip sudo python-software-properties && \
    apt-get clean

ENV KOHA_ADMINUSER admin
ENV KOHA_ADMINPASS secret
ENV KOHA_INSTANCE name
ENV KOHA_ZEBRAUSER zebrauser
ENV KOHA_ZEBRAPASS lkjasdpoiqrr

#######
# Salt Configuration
#######

# Install salt from git
#RUN wget -O- --quiet https://bootstrap.saltstack.com | \
#    sudo sh -s -- -g https://github.com/saltstack/salt.git git v2014.7.0rc3 || true  

# Install stable salt minion, currently 2014.1.11
RUN add-apt-repository 'deb http://debian.saltstack.com/debian wheezy-saltstack main' && \
    wget -q -O- "http://debian.saltstack.com/debian-salt-team-joehealy.gpg.key" | apt-key add - && \
    sudo apt-get update && sudo apt-get install -y salt-minion

# for now - only masterless salt is used
RUN echo "file_client: local\nmaster: localhost\n" > /etc/salt/minion

# Preseed local master-minion, in case we need master against gitfs remote
#RUN cd /tmp && \
#    salt-key --gen-keys=master-minion && \
#    mkdir -p /etc/salt/pki/master/minions && \
#    cp master-minion.pub /etc/salt/pki/master/minions/master-minion && \
#    mkdir -p /etc/salt/pki/minion && \
#    cp master-minion.pub /etc/salt/pki/minion/minion.pub && \
#    cp master-minion.pem /etc/salt/pki/minion/minion.pem


#######
# Salt Provisioning
# Package installs
#######

ADD ./pillar /srv/pillar/
COPY ./pillar/koha/admin.sls.example /srv/pillar/koha/admin.sls

ADD ./salt/common/init.sls /srv/salt/common/init.sls
RUN salt-call --local --retcode-passthrough state.sls common

ADD ./salt/koha/watir.sls /srv/salt/koha/watir.sls
RUN salt-call --local --retcode-passthrough state.sls koha.watir

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
RUN salt-call --local --retcode-passthrough state.sls koha.common

# Koha-restful API
ADD ./salt/koha/restful.sls /srv/salt/koha/restful.sls
ADD ./salt/koha/restful-config.sls /srv/salt/koha/restful-config.sls
ADD ./salt/koha/files/koha-restful-config.yaml /srv/salt/koha/files/koha-restful-config.yaml
RUN salt-call --local --retcode-passthrough state.sls koha.restful

#######
# Salt Provisioning - step 2
# Configuration files
#######

# Apache settings
ADD ./salt/koha/apache2.sls /srv/salt/koha/apache2.sls
ADD ./salt/koha/files/apache.tmpl /srv/salt/koha/files/apache.tmpl
#RUN salt-call --local --retcode-passthrough state.sls koha.apache2

# Koha instance settings
ADD ./salt/koha/sites-config.sls /srv/salt/koha/sites-config.sls
ADD ./salt/koha/files/koha-sites.conf /srv/salt/koha/files/koha-sites.conf
ADD ./salt/koha/files/passwd /srv/salt/koha/files/passwd
#RUN salt-call --local --retcode-passthrough state.sls koha.sites-config

# Koha DB settings
ADD ./salt/koha/createdb.sls /srv/salt/koha/createdb.sls
ADD ./salt/koha/config.sls /srv/salt/koha/config.sls
#RUN salt-call --local --retcode-passthrough state.sls koha.config

# Koha automated webinstaller
ADD ./salt/koha/webinstaller.sls /srv/salt/koha/webinstaller.sls
ADD ./salt/koha/files/KohaWebInstallAutomation.rb /srv/salt/koha/files/KohaWebInstallAutomation.rb
ADD ./salt/koha/files/updatekohadbversion.sh /srv/salt/koha/files/updatekohadbversion.sh
ADD ./salt/koha/webinstaller.sls /srv/salt/koha/webinstaller.sls

#######
# Setup logstash-forwarder
#######

# install logstash-forwarder from official repositories (note: quite old version as of 16.10.2014)
RUN wget -qO - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add -
RUN echo "deb http://packages.elasticsearch.org/logstashforwarder/debian stable main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -yq logstash-forwarder

# add the config file
ADD https://raw.githubusercontent.com/digibib/ls.ext/master/salt/koha/files/logstash-forwarder.conf /etc/logstash-forwarder

# add certificate
RUN mkdir -p /etc/pki/tls/certs
ADD https://raw.githubusercontent.com/digibib/ls.ext/master/salt/koha/files/logstash-forwarder.crt /etc/pki/tls/certs/logstash-forwarder.crt

# Remove option to log to syslog (syslog is not running in container)
RUN sed -i 's/-log-to-syslog//' /etc/init.d/logstash-forwarder

ENV HOME /root
WORKDIR /root

COPY docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]

EXPOSE 8080 8081

# Might be koha-common (Zebra) should be stand-alone container
CMD ["/usr/bin/tail", "-f", "/var/log/apache2/access.log", "/var/log/koha/name/intranet-error.log", "/var/log/koha/name/opac-error.log", "/var/log/koha/name/zebra-error.log", "/var/log/apache2/other_vhosts_access.log"]
