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
  VERSION="1.12.5-0~ubuntu-$(lsb_release -c -s)"
  INSTALLED=`dpkg -l | grep docker-engine | awk '{print $3}'`
  if [ $VERSION = "$INSTALLED" ] ; then
    echo "docker version $VERSION already installed";
  else
    echo "Installing docker version $VERSION ...";
    sudo apt-get purge --assume-yes --quiet docker-engine >/dev/null 2>&1 || true
    sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    echo "deb https://apt.dockerproject.org/repo ubuntu-$(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/docker.list
    sudo apt-get update
    sudo apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
      install linux-image-extra-$(uname -r) make git docker-engine=$VERSION
    sudo echo 'DOCKER_OPTS="--storage-driver=aufs"' > /etc/default/docker
    sudo service docker restart
    echo "docker installed."
  fi

  echo -e "\n2) Installing Docker-compose\n"
  COMPOSEVERSION=1.9.0
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

CMD="sudo KOHAPATH=${KOHAPATH} GITREF=${GITREF} docker-compose -f common.yml"

case "$KOHAENV" in
  'dev')
  $CMD -f dev.yml build koha
  $CMD -f dev.yml up -d
  ;;
  'patched')
  $CMD -f patched.yml build koha
  $CMD -f patched.yml up -d
  ;;
  'build'|*)
  $CMD build koha
  $CMD up -d
  ;;
esac
