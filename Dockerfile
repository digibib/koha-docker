FROM ubuntu
 
RUN apt-get update

#Utilities
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget less curl git nmap socat netcat tree htop unzip sudo

RUN wget -O- --quiet https://bootstrap.saltstack.com | \
    sudo sh -s -- -g https://github.com/saltstack/salt.git git v2014.7.0rc2 || true

#Docker client only
RUN wget -O /usr/local/bin/docker https://get.docker.io/builds/Linux/x86_64/docker-latest && \
    chmod +x /usr/local/bin/docker


#Preseed local master-minion
RUN cd /tmp && \
    salt-key --gen-keys=master-minion && \
    mkdir -p /etc/salt/pki/master/minions && \
    cp master-minion.pub /etc/salt/pki/master/minions/master-minion && \
    mkdir -p /etc/salt/pki/minion && \
    cp master-minion.pub /etc/salt/pki/minion/minion.pub && \
    cp master-minion.pem /etc/salt/pki/minion/minion.pem

RUN echo "file_client: local\nmaster: localhost" > /etc/salt/minion

#######
# Salt Configuration
#######

ADD ./pillar /srv/pillar/
ADD ./salt/koha/files /srv/salt/koha/files

ADD ./salt/common/init.sls /srv/salt/common/init.sls
RUN salt-call --local state.sls common

ADD ./salt/koha/init.sls /srv/salt/koha/init.sls
RUN salt-call --local state.sls koha

ADD ./salt/koha/apache2.sls /srv/salt/koha/apache2.sls
RUN salt-call --local state.sls koha.apache2

ADD ./salt/koha/common.sls /srv/salt/koha/common.sls
RUN salt-call --local state.sls koha.common

ADD ./salt/koha/sites-config.sls /srv/salt/koha/sites-config.sls
RUN salt-call --local state.sls koha.sites-config

ADD ./salt/mysql/server.sls /srv/salt/mysql/server.sls
RUN salt-call --local state.sls mysql.server

ADD ./salt/koha/createdb.sls /srv/salt/koha/createdb.sls
RUN salt-call --local state.sls koha.createdb

ADD ./salt/koha/config.sls /srv/salt/koha/config.sls
RUN salt-call --local state.sls koha.config

ADD ./salt/koha/webinstaller.sls /srv/salt/koha/webinstaller.sls
RUN salt-call --local state.sls koha.webinstaller

ADD ./salt/koha/restful.sls /srv/salt/koha/restful.sls
RUN salt-call --local state.sls koha.restful

ENV HOME /root
WORKDIR /root
EXPOSE 4506 8080

CMD /etc/init.d/koha-common && /etc/init.d/koha-common start && /usr/sbin/apache2ctl -D FOREGROUND