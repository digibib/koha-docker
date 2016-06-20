## Kohadev README

This Docker image builds on a Koha docker image `digibib/koha:$TAG` from Dockerhub and
includes a complete Koha development install setup from git source.

It is very simple to setup and ready for use.

It is also preinstalled with git-bz tools to patch from bugzilla and qa-tools for testing

## Install

`make` will setup Vagrant box and do a default install, build and run

`make upgrade` pulls the latest build image from Docker registry hub.

`make browser` runs a browser inside Vagrant box for testing

`make logs-f` runs a tail on logs inside container

`make test`  test sanity of koha container

## Usage

All environment variables used in setup can be overridden. 
Complete list of environment variables is in Dockerfile.

To start a koha development container, use one of the examples below.
NB! remember to modify your credentials for admin login and bugzilla setup.

Example using makefile:

```
KOHA_ADMINUSER="superadmin" KOHA_ADMINPASS="superpass" AUTHOR_NAME='"Roger Rabbit"' AUTHOR_EMAIL="rabbit@mail.com" BUGZ_USER="rabbit@mail.com" BUGZ_PASS=wildguess make run
```

Example from inside Vagrant box:

```
sudo docker run -d --name kohadev_docker \
  -p 80:80 -p 8080:8080 -p 8081:8081 \
  -e KOHA_ADMINUSER="superadmin" \
  -e KOHA_ADMINPASS="superpass" \
  -e AUTHOR_NAME="Roger Rabbit" \
  -e AUTHOR_EMAIL=rabbit@mail.com \
  -e BUGZ_USER=rabbit@mail.com \
  -e BUGZ_PASS=rabbitz \
  --cap-add=SYS_NICE --cap-add=DAC_READ_SEARCH \
  -t digibib/kohadev
```

## Patching and testing

To run koha with pathces from bugzilla, a simple `make patch` target is available.
It will create a branch `sandbox` from the koha repo, in which it will apply selected patches.

Example:

```PATCHES="bugid1 bugid2 ..." make patch```
will patch repo with one or more bugzilla patches

To cleanup and reset git from HEAD:
```make reset_git_hard```
(actually deletes repo and makes new clone, which is faster than git pull...)
