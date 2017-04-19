## Koha Builder README

This docker image is for generation of custom koha debian packages.

In short, it:

* creates a build system for Koha using debian:jessie as starting point.
* downloads all dependencies and source for a given koha tag
* optionally applies given patches from koha bugzilla
* optionally applies custom patches from patches subfolder
* runs koha tests and, if successful, builds debian packages

Documentation can be found on project [wiki](https://github.com/digibib/koha-docker/wiki)
