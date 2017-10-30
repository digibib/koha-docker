#!/usr/bin/env bash
if [ "$#" -ne 2 ]; then
  echo "provision.sh takes exactly two parameters:"
  echo "  provision.sh [kohaenv] [kohapath]"
fi
export KOHAENV=$1
export KOHAPATH=$2
echo -e "\n Provisioning for $KOHAENV env, KOHAENV=$KOHAENV, KOHAPATH=$KOHAPATH\n"
if [[ `uname -s` == 'Linux' && "$LSENV" != 'prod' ]]; then
echo -e "\n1) Installing Docker\n"
  VERSION="17.09.0~ce-0~ubuntu"
  INSTALLED=`dpkg -l | grep docker-engine | awk '{print $3}'`
  if [ $VERSION = "$INSTALLED" ] ; then
    echo "docker version $VERSION already installed";
  else
    echo "Installing docker version $VERSION ...";
    sudo apt-get purge --assume-yes --quiet docker-engine docker-ce docker.io >/dev/null 2>&1 || true
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
    sudo apt-get update
    sudo apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
      install linux-image-extra-$(uname -r) linux-image-extra-virtual make git docker-ce=$VERSION
    sudo echo 'DOCKER_OPTS="--storage-driver=aufs"' > /etc/default/docker
    sudo service docker restart
    echo "docker installed."
  fi

  echo -e "\n2) Installing Docker-compose\n"
  COMPOSEVERSION=1.16.1
  INSTALLED=`docker-compose -v | cut -d',' -f1 | cut -d' ' -f3`
  if [ $COMPOSEVERSION = "$INSTALLED" ] ; then
    echo "docker-compose version $COMPOSEVERSION already installed"
  else
    sudo bash -c "curl -s -L https://github.com/docker/compose/releases/download/$COMPOSEVERSION/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
    sudo chmod +x /usr/local/bin/docker-compose
  fi
else
  echo "Cannot provision for OSX; please install docker & docker-compose yourself"
fi

echo -e "\n3) Provisioning system with docker-compose\n"
cd "$KOHAPATH/docker-compose"
source docker-compose.env

if [ "$KOHAPATH" = "/vagrant" ]; then
  export MOUNTPATH="/mnt"
else
  export MOUNTPATH=$KOHAPATH
fi

CMD="sudo KOHAPATH=${KOHAPATH} GITREF=${GITREF} KOHA_RELEASE=${KOHA_RELEASE} KOHA_BUILD=${KOHA_BUILD} docker-compose -f common.yml"

case "$KOHAENV" in
  'dev')
  $CMD -f dev.yml build koha_dev
  $CMD -f dev.yml up -d
  ;;
  'patched')
  $CMD -f patched.yml build koha_patched
  $CMD -f patched.yml up -d
  ;;
  'build'|*)
  $CMD -f build.yml build koha_build
  $CMD -f build.yml up -d
  ;;
esac
