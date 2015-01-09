Building a Koha Docker Container - provisioned with salt
===

## Feature

Using vagrant, set up a box that will build and provision a Docker container using salt states.

## Usage

All docker relevant files are in /vagrant/koha, so building an image manually is done by
```sudo docker build -t kohaimage /vagrant/koha```

Using Makefile, the following commands are available:

`make` : sets up and provisions virtual box

`make reload` : reloads box

`make halt` : stops virtual box

`make up` : starts box (no provisioning)

`make provision`: provision box

`make build` : build docker image (slooow)

`make mysql_start` : setup a mysql container

`make mysql_stop` : stop and remove a running mysql container

`make run` : run/start koha container and link to running mysql container 

`make browser` : start firefox in box and test container

`make stop` : stop docker container

`make delete` : stop and remove container

`make nsenter` : open shell inside container

`make clean` : purge entire virtual box

`make push` : creates a new tag based on git revision and push docker image to docker registry

