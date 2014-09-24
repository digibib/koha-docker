Koha in Docker - provisioned with salt
===

Using vagrant, set up a box that will build and provision a Docker container using salt states.

## Usage

All docker relevant files are in /vagrant, so building an image manually is done by
```sudo docker build -t kohaimage /vagrant```

Using Makefile, the following commands are available:

`make` : sets up and provisions virtual box

`make reload` : reloads box

`make halt` : stops virtual box

`make up` : starts box (no provisioning)

`make provision`: provision box

`make build` : build docker image (slooow)

`make run` : run/start docker container 

`make stop` : stop docker container

`make delete` : stop and remove container

`make nsenter` : open and inspect container

`make clean` : purge entire virtual box
