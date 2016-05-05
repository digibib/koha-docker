#!/bin/bash -e
# Pull Koha either from GITREF or from TAGGED version
echo "GITREF: ${GITREF}"
echo "KOHA_VERSION: ${KOHA_VERSION}"

if [ -z "$GITREF" ] && [ -z "$KOHA_VERSION" ]; then
	echo "Need either GITREF or KOHA_VERSION"
	exit 1
fi

mkdir -p /koha && cd /koha
if [ "$GITREF" ]; then
	curl -s -o koha.tar.gz https://codeload.github.com/Koha-Community/Koha/legacy.tar.gz/${GITREF}
else
  RES=`curl -iso /dev/null -w "%{http_code}" http://download.koha-community.org/koha-${KOHA_VERSION}.tar.gz`
  if [ $RES -eq 200 ]; then
    curl -s -o koha.tar.gz http://download.koha-community.org/koha-${KOHA_VERSION}.tar.gz
  else
    echo "Trying old_releases archive..."
    curl -s -o koha.tar.gz http://download.koha-community.org/old_releases/koha-${KOHA_VERSION}.tar.gz
  fi
fi

tar -C /koha --strip-components=1 -xzf koha.tar.gz
rm -rf koha.tar.gz
