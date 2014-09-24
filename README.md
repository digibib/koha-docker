Koha in Docker - provisioned with salt
===

Using vagrant, set up a box that will build and provision a Docker container using salt states.

## Usage

All docker relevant files are in /vagrant, so building an image manually is done by
```sudo docker build -t kohaimage /vagrant```

Using Makefile, the following commands are available:

`make` : sets up and provisions virtual box

`reload` : reloads box

`halt` : stops virtual box

`up` : starts box (no provisioning)

`provision`: provision box

`build` : build docker image (slooow)

`run` : run/start docker container 

`stop` : stop docker container

`delete` : stop and remove container

`nsenter` : open and inspect container

`clean` : purge entire virtual box
