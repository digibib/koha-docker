## Custom patches dir

Docker container exposes volume /patches which will be used to import custom patches to Koha.

By default, this dir will be mounted as volume by docker param:

    -v /vagrant/koha-patched/patches:/patches

Any file in this dir ending in .patch will be applied to codebase.

To impose a certain ordering, please prefix with a three digit number, e.g.:

    010-bug11858_RFID_for_circulation.patch

Any failed patch will terminate the build process.
