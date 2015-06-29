## Koha Builder README

This docker image is for generation of custom koha debian packages.

In short, it:

* creates a build system for Koha using debian:wheezy as starting point.
* downloads all dependencies and source for a given koha tag 
* optionally applies given patches from koha bugzilla
* optionally applies custom patches from patches subfolder
* runs koha tests and, if successful, builds debian packages

Using docker magic, it is very simple to use 

## Included

* A vagrant setup for creating a virtual box from a Vagrantfile
* A stripped and customized git-bz for patching a non-git source tree of Koha
* A Makefile to simplify runs

## Simple usage

`make` will setup Vagrant box and do a default install, build and run with defaults

`make logs-f` runs a tail on logs inside container

`make delete` deletes it all

## Advanced Usage

All environment variables used in setup can be overridden. 
For complete list of environment variables see `Dockerfile`.

Most important env:
```
KOHA_VERSION (release version of koha source, must be set in Dockerfile)
TEST_QA      (default: 0 - don't run QA tests)
KOHABUGS     (space separated list of koha bugz to patch)
```

Example using makefile:

```
make build
KOHABUGS="bugID1 bugID2" make run
```
This will build koha from version set in Dockerfile (KOHA_VERSION)
Then it will start a container, apply patches bugID1 and bugID2, build debian packages
and leave them in /vagrant/koha-patched/debian

Example from inside Vagrant box:

```
docker run --name koha_patched_docker \
  -v /output:/debian \
  -v /vagrant/koha-patched/patches:/patches \
  -e KOHABUGS="bugID1 bugID2" \
  -t digibib/koha-patched
```
This will do same, except debian packages will be found in /output on host.
Also, any files in host dir /vagrant/koha-patched/patches with extension .patch will be applied.

## Koha specifics

Note, there is a new patching method for database updates:
  `http://wiki.koha-community.org/wiki/Database_updates#Using_the_new_update_procedure`

In short, this means database changes are inserted as separate files in the patch:
```
$ cat ./installer/data/mysql/atomicupdate/bug_14242-add_mynewpref_syspref.sql:
INSERT IGNORE INTO systempreferences (variable,value,explanation,options,type) VALUES ('MyNewPref', 'value', 'explanation', NULL, 'Free');
```

Then it is no longer a problem to apply multiple patches with database changes.
