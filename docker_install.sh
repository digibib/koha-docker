#!/bin/bash -e

echo -e "\n1) Installing Docker\n"
VERSION="1.10.3-0~$(lsb_release -c -s)"
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
