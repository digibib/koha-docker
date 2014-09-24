Koha in Docker - provisioned with salt
===

Using vagrant, set up a box that will build and provision a Docker container
using salt states.

`make` will, for now, only setup a Virtualbox that installs docker

`vagrant ssh` to enter box.

All docker relevant files are in /vagrant, so building an image is done by
```sudo docker build -t kohaimage /vagrant```
