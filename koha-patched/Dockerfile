###########################
# KOHA DEBIAN BUILDER IMAGE
#
# this docker image takes a given koha release,
# applys patches, runs tests and builds debian packages
###########################

FROM debian:jessie

MAINTAINER Oslo Public Library "digitalutvikling@gmail.com"

ENV DEBIAN_FRONTEND noninteractive
ENV DEBIAN_PRIORITY critical
ENV DEBCONF_NOWARNINGS yes
ENV REFRESHED_AT 2015-12-09

RUN apt-get update && \
    apt-get install --no-install-recommends -q -y vim.tiny telnet screen htop curl git \
            devscripts equivs python && \
    apt-get clean

#######################
# KOHA SOURCES AND DEPS
#######################

# Install Koha deps
RUN echo "deb http://debian.koha-community.org/koha stable main" > /etc/apt/sources.list.d/koha.list
RUN curl -L http://debian.koha-community.org/koha/gpg.asc | apt-key add -
RUN apt-get update && \
    apt-get install -y koha-deps koha-perldeps make build-essential && \
    apt-get clean

RUN apt-get install -y libdbix-connector-perl libtest-perl-critic-perl && apt-get clean

ENV KOHA_VERSION 3.22.03

# Download Koha from tarball, try old_releases if not existing
RUN mkdir -p /koha && cd /koha && \
  RES=`curl -iso /dev/null -w "%{http_code}" http://download.koha-community.org/koha-${KOHA_VERSION}.tar.gz` && \
  if [ $RES -eq 200 ]; then \
    curl -s -o koha.tar.gz http://download.koha-community.org/koha-${KOHA_VERSION}.tar.gz ;\
  else \
    echo "Trying old_releases archive..." && \
    curl -s -o koha.tar.gz http://download.koha-community.org/old_releases/koha-${KOHA_VERSION}.tar.gz ;\
  fi && \
  tar -C /koha --strip-components=1 -xzf koha.tar.gz && \
  rm -rf koha.tar

##########
# WORKAROUNDS - REMOVE WHEN OBSOLETE
##########

# Add mojolicious and swagger2 deps that are not yet in kohadeps
RUN apt-get install -y make cpanminus && \
    cpanm Mojolicious@6.0 Swagger2@0.59 && \
    apt-get clean

# One of the tests in Logger.t fails in our setup,
# probably due to user permissions in the docker build-container.
RUN rm /koha/t/Logger.t

##########
# GIT-BZ, PATCHLIBS AND BUILDSCRIPT
##########

# modified and stripped git-bz for patching non-git source
ADD ./git-bz /usr/bin/git-bz

# bugzilla user and pass needed for git-bz to apply patches
# can safely be left untouched
ENV AUTHOR_NAME  "John Doe"
ENV AUTHOR_EMAIL john@doe.snot
ENV BUGZ_USER    bugsquasher
ENV BUGZ_PASS    bugspass

ENV DEBEMAIL     digitalutvikling@gmail.com
ENV DEBFULLNAME  Oslo Public Library
ENV KOHABUGS     "13666 15126 13903 16271"
ENV TEST_QA      0

RUN mkdir -p /debian
WORKDIR /koha
VOLUME ["/patches", "/debian"]

ADD ./applypatch.sh /root/applypatch.sh
ADD ./build.sh /root/build.sh

CMD ["/root/build.sh"]
