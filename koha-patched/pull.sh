#!/bin/bash -e
# Pull Koha either from GITREF or from TAGGED version
echo "GITREF: ${GITREF}"
echo "KOHA_RELEASE: ${KOHA_RELEASE}"

if [ -z "$GITREF" ] && [ -z "$KOHA_RELEASE" ]; then
	echo "Need either GITREF or KOHA_RELEASE"
	exit 1
fi

mkdir -p /koha && cd /koha
if [ "$GITREF" ]; then
	curl -sSk -o koha.tar.gz https://codeload.github.com/digibib/Koha/legacy.tar.gz/${GITREF}
else
  RES=`curl -sSk -Iso /dev/null -w "%{http_code}" https://codeload.github.com/digibib/Koha/tar.gz/release/${KOHA_RELEASE}`
  if [ $RES -eq 200 ]; then
    curl -sSk -o koha.tar.gz https://codeload.github.com/digibib/Koha/tar.gz/release/${KOHA_RELEASE}
  else
    echo "Trying old_releases archive..."
    curl -sSk -o koha.tar.gz https://codeload.github.com/digibib/Koha/tar.gz/old_releases/${KOHA_RELEASE}
  fi
fi

tar -C /koha --strip-components=1 -xzf koha.tar.gz
rm -rf koha.tar.gz
