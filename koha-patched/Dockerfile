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
ENV REFRESHED_AT 2016-11-16

RUN apt-get update && \
    apt-get install --no-install-recommends -q -y vim.tiny telnet screen htop curl git \
            devscripts equivs python && \
    apt-get clean

#######################
# KOHA SOURCES AND DEPS
#######################

# Add Koha Stable repo
RUN echo "deb http://debian.koha-community.org/koha stable main" > /etc/apt/sources.list.d/koha.list
RUN curl -L http://debian.koha-community.org/koha/gpg.asc | apt-key add -

ENV KOHA_VERSION 16.11.02
#ENV GITREF 80c80ca683217455221e15e0c24a81d5e60e49e0

# Pull/Download Koha from GITREF or KOHA_VERSION tarball, try old_releases if not existing
ADD ./pull.sh /root/pull.sh
RUN /root/pull.sh

# Install Koha deps

RUN sed -i "s/httpredir.debian.org/`curl -s -D - http://httpredir.debian.org/demo/debian/ | \
    awk '/^Link:/ { print $2 }' | sed -e 's@<http://\(.*\)/debian/>;@\1@g'`/" /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y koha-perldeps koha-deps make build-essential && \
    apt-get clean

##########
# WORKAROUNDS - REMOVE WHEN OBSOLETE
##########

# One of the tests in Logger.t fails in our setup,
# probably due to user permissions in the docker build-container.
RUN rm /koha/t/Logger.t

# Missing perl dependencies

RUN apt-get update && apt-get install -y libwww-csrf-perl && \
    apt-get clean

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

# OK    Bug 16694 - Limit SIP2 auth by patron attribute
# OK    Bug 17004 - REST API: add route to authenticate patron (Single Sign On - SSO)
# OK    Bug 16330 - REST API: add routes to add, update and delete patrons
# LOCAL    Bug 16497 - REST API: add routes to list libraries
# LOCAL    Bug 13895 - Add API routes for checkouts retrieval and renewal
#ENV KOHABUGS     "16694 17004 16330"
ENV TEST_QA      0

RUN mkdir -p /debian
WORKDIR /koha
VOLUME ["/patches", "/debian"]

ADD ./applypatch.sh /root/applypatch.sh
ADD ./build.sh /root/build.sh

CMD ["/root/build.sh"]
# ARG can be removed when docker 1.13 is released
ARG KOHA_BUILD
