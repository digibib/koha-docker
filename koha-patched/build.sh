#!/bin/bash
set -e

################
# BUILD KOHA DEBIAN PACKAGES
# NB! PBUILDER MUST BE RUN WITH --privileged mode
################
# ENV KOHA_VERSION
# ENV KOHABUGS
# ENV DEBEMAIL     digitalutvikling@gmail.com
# ENV DEBFULLNAME  Oslo Public Library
# ENV TEST_QA      0
# VOLUME ["/debian", "/patches"]
# WORKDIR /koha
################

cleanup() {
    rv=$?
    echo "$MSG"
    if [ -n $RETVAL ];
    then
      exit $RETVAL
    else
      exit $rv
    fi
}
trap "cleanup" INT TERM EXIT

echo "Configuring bugzilla..." && \
  git config --global bz.default-tracker bugs.koha-community.org && \
  git config --global bz.default-product Koha && \
  git config --global bz-tracker.bugs.koha-community.org.path /bugzilla3 && \
  git config --global bz-tracker.bugs.koha-community.org.bz-user $BUGZ_USER && \
  git config --global bz-tracker.bugs.koha-community.org.bz-password $BUGZ_PASS

##########
# PATCHING
##########

echo "Patching..."

# Patch from bugzilla
for bugid in ${KOHABUGS}; do \
  echo "Patching from bugzilla bug $bugid"
  /root/applypatch.sh --bugid $bugid /koha ; \
done

# Patch with custom patches
for patch in $(find /patches -name *.patch | sort -n); do \
  if [ -f "$patch" ]; then \
    echo "Patching local patch $patch"
    /root/applypatch.sh --patch $patch /koha ; \
  fi \
done

############
# CHANGELOG AND BUILD DEPS
############

mk-build-deps -t "apt-get update"
mk-build-deps -t "apt-get install libxml2-utils"
mk-build-deps -t "apt-get -y --no-install-recommends --fix-missing" -i "debian/control"

dch --force-distribution -D "wheezy" \
    --newversion "${KOHA_VERSION}+$(date +%Y%m%d)~patched" \
    "Patched version of koha ${KOHA_VERSION} - Bugpatches included: ${KOHABUGS}"
dch --append "Local patches:"
for patch in $(find /patches -name *.patch); do \
  if [ -f "$patch" ]; then \
    dch --append "${patch##/*/}"    # strip path of patch
  fi \
done
dch --release "Patched version of koha ${KOHA_VERSION}"

# Build
cd /koha && \
    dpkg-buildpackage -b -us -uc

cp *.deb ../*.deb ../*.changes /debian
