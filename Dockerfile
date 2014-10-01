#######
# Debian Wheezy build of Koha - Provisioned by Salt
#######

FROM debian:wheezy
 
RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget less curl git nmap socat netcat tree htop unzip sudo

ENV KOHA_ADMINUSER admin
ENV KOHA_ADMINPASS secret
ENV KOHA_INSTANCE name
ENV KOHA_ZEBRAUSER zebrauser
ENV KOHA_ZEBRAPASS lkjasdpoiqrr

#######
# Salt Configuration
#######

RUN wget -O- --quiet https://bootstrap.saltstack.com | \
    sudo sh -s -- -g https://github.com/saltstack/salt.git git v2014.7.0rc2 || true

# for now - only masterless salt is used
RUN echo "file_client: local\nmaster: localhost" > /etc/salt/minion

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
COPY ./pillar/admin.sls.example /srv/pillar/koha/admin.sls

ADD ./salt/common/init.sls /srv/salt/common/init.sls
RUN salt-call --local state.sls common

ADD ./salt/koha/watir.sls /srv/salt/koha/watir.sls
RUN salt-call --local state.sls koha.watir

ADD ./salt/koha/init.sls /srv/salt/koha/init.sls 
RUN salt-call --local state.sls koha

# Need mysql server to create initial db
ADD ./salt/mysql/server.sls /srv/salt/mysql/server.sls
RUN salt-call --local state.sls mysql.server

# Koha common settings
ADD ./salt/koha/common.sls /srv/salt/koha/common.sls
ADD ./salt/koha/files/koha-common.cnf /srv/salt/koha/files/koha-common.cnf
ADD ./salt/koha/files/koha-conf.xml.tmpl /srv/salt/koha/files/koha-conf.xml.tmpl
ADD ./salt/koha/files/zebra.passwd.tmpl /srv/salt/koha/files/zebra.passwd.tmpl
RUN salt-call --local state.sls koha.common

#######
# Salt Provisioning - step 2
# Configuration files
#######

# Apache settings
ADD ./salt/koha/apache2.sls /srv/salt/koha/apache2.sls
ADD ./salt/koha/files/apache.tmpl /srv/salt/koha/files/apache.tmpl
#RUN salt-call --local state.sls koha.apache2

# Koha instance settings
ADD ./salt/koha/sites-config.sls /srv/salt/koha/sites-config.sls
ADD ./salt/koha/files/koha-sites.conf /srv/salt/koha/files/koha-sites.conf
ADD ./salt/koha/files/passwd /srv/salt/koha/files/passwd
#RUN salt-call --local state.sls koha.sites-config

# Koha DB settings
ADD ./salt/koha/createdb.sls /srv/salt/koha/createdb.sls
ADD ./salt/koha/config.sls /srv/salt/koha/config.sls
#RUN salt-call --local state.sls koha.config

# Koha automated webinstaller
ADD ./salt/koha/webinstaller.sls /srv/salt/koha/webinstaller.sls
ADD ./salt/koha/files/KohaWebInstallAutomation.rb /srv/salt/koha/files/KohaWebInstallAutomation.rb
ADD ./salt/koha/files/updatekohadbversion.sh /srv/salt/koha/files/updatekohadbversion.sh
ADD ./salt/koha/webinstaller.sls /srv/salt/koha/webinstaller.sls

# Koha-restful API
ADD ./salt/koha/restful.sls /srv/salt/koha/restful.sls
ADD ./salt/koha/files/koha-restful-config.yaml /srv/salt/koha/files/koha-restful-config.yaml
#RUN salt-call --local state.sls koha.restful

ENV HOME /root
WORKDIR /root

COPY docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]

EXPOSE 8080 8081

# Might be koha-common (Zebra) should be stand-alone container
CMD /etc/init.d/koha-common start && \
    /usr/bin/apache2ctl -D FOREGROUND
