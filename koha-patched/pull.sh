#!/bin/bash -e
echo "KOHA_RELEASE: ${KOHA_RELEASE}"

if [ -z "$KOHA_RELEASE" ]; then
	echo "Need KOHA_RELEASE"
	exit 1
fi

mkdir -p /koha && cd /koha
RES=`curl -sSk -Iso /dev/null -w "%{http_code}" https://gitlab.deichman.no/digibib/Koha/repository/release/${KOHA_RELEASE}/archive.tar.gz`
if [ $RES -eq 200 ]; then
  curl -sSk -o koha.tar.gz https://gitlab.deichman.no/digibib/Koha/repository/release/${KOHA_RELEASE}/archive.tar.gz
else
  echo "Failed getting tagged release ... giving up!"
  exit 1
fi

tar -C /koha --strip-components=1 -xzf koha.tar.gz
rm -rf koha.tar.gz
