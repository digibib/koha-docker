Koha Docker Container
===

This project builds a [Docker](https://www.docker.com/) image containg an installation of the library system [Koha](http://koha-community.org/). 

If you don't want to build the Docker image yourself we automatically build and push new versions of the image to [Docker Hub Registry](https://registry.hub.docker.com/u/digibib/koha/) on every push to [this GitHub repository](https://github.com/digibib/koha-salt-docker). New images are given tags that correspond to the git head revisions in the git repo. See the section [Using the Koha Docker image](#using-the-Koha-docker-image) for more information.

The Docker image produced uses currently released [Debian packages of Koha](http://wiki.koha-community.org/wiki/Koha_on_Debian). 

The image will on startup go through the steps of the Koha Webinstaller accepting default settings, and choosing MARC-flavour: MARC21.

## Using the Koha Docker image

This section assumes [some](https://www.docker.com/whatisdocker/) [understanding](https://docs.docker.com/introduction/understanding-docker/) [of Docker](http://www.dockerbook.com/), and a machine (virtual or physical) capable of running Docker.

For mysql and apache to work properly in docker, you need to add some capabilities to the container:

`MKNOD`: mysql needs making nodes
`DAC_READ_SEARCH`: directory read and permission checks
`SYS_NICE`: allow nice processes

### Download image from Docker Hub Registry

```docker pull digibib/koha:[tag/revision]```

The `tag/revision` should correspond to the git revisions in this git repository.

### Starting a Koha Docker container

<pre>docker run -d --name koha_docker \
  --cap-add=DAC_READ_SEARCH --cap-add=SYS_NICE --cap-add=MKNOD \
	-p 6001:6001 -p 8080:8080 -p 8081:8081 \
	-t digibib/koha:[tag/revision]
</pre>

The `tag/revision` is as above.

It takes a little while for the Koha startup to complete.

### Accessing Koha

Starting Koha as explained above makes the OPAC available on port 8080 (http) and Intra on port 8081 (http). The SIP-server is available on port 6001 (tcp).

### Credentials

You should set credentials for the Koha instance database user on container startup (to avoid default values), you can also set the Koha instance name, and SIP-server settings :

<pre>docker run -d --name koha_docker \
  --cap-add=DAC_READ_SEARCH --cap-add=SYS_NICE --cap-add=MKNOD \
	-p 6001:6001 -p 8080:8080 -p 8081:8081 \
	-e KOHA_INSTANCE=[koha instance name, default: name] \
	-e KOHA_ADMINUSER=[db admin user name, default: admin] \
	-e KOHA_ADMINPASS=[db admin password, default: secret] \
	-e SIP_WORKERS=[no of workers, default: 3] \
	-e SIP_AUTOUSER1=[username, default: autouser] \
	-e SIP_AUTOPASS1=[password, default: autopass] \
	-t digibib/koha
</pre>

### External MySql

Note: Koha is p.t. incompatible with versions > 5.6.20.

We recommend keeping mysql outside of the image, and running as a separate docker container.
The official mysql docker image is perfect for this. To spin up a mysql container:

```
docker run -d --name koha_mysql --cap-add=MKNOD \
  -e MYSQL_DATABASE=koha_name \
  -e MYSQL_PASSWORD=secretpass \
  -e MYSQL_ROOT_PASSWORD=secretrootpass \
  -e MYSQL_USER=mysqluser \
  -p 3306:3306 -t mysql:5.6.20 \
  mysqld --datadir=/var/lib/mysql --user=mysql --bind-address=0.0.0.0
```

You can then spin up a koha container and connect with `--link koha_mysql` and Koha will automatically be set up against the external mysql.

For permanent storage, we also recommend using a docker volume for the `/var/lib/mysql` folder.

### Logs

Log entries from a number of logs will be concatenated into standard out and can be seen using:
```docker logs koha_docker```

## Installing virtual build machine

Using vagrant is not something we recommend. It is an extra and unneccessary virtualization.

But to install vagrant:

1. Install virtualbox and vagrant:
    - Ubuntu:
        * `sudo apt-get install virtualbox`
        * vagrant > 1.7.2 - install deb manually: https://www.vagrantup.com/downloads.html
    - OSX: We recommend using [homebrew](http://brew.sh/) and [homebrew cask](http://caskroom.io/), but you can install these manually if you prefer (see download links).
        * `brew cask install virtualbox` -- or [Virtualbox Downloads](https://www.virtualbox.org/wiki/Downloads)
        * `brew cask install vagrant` -- or [Vagrant Downloads](https://www.vagrantup.com/downloads)
    - Windows:
        * Download and install "VirtualBox platform package" for Window hosts: [Virtualbox Downloads](https://www.virtualbox.org/wiki/Downloads)
        * Download and install Vagrant for Windows: [Vagrant Downloads](https://www.vagrantup.com/downloads)
        * Reboot your machine.
        * [Install Cygwin] (https://cygwin.com/install.html)
          - Choose the following packages:
            * git
            * make
            * openssh
          - We also recommend these:
            * curl
            * git-completion
        * After installing Cygwin/X Windows users should use the program "XWin Server" for commands like git, make etc.
2. Clone this repo from the command line (in a directory of your choice):
   ```git clone https://github.com/digibib/ls.ext.git```
3. `cd ls.ext` into your cloned repo.
4. From the command line run: `make` to bootstrap the environment.

## Building the Koha Docker image in the build machine

If you want to work purely virtual, use VAGRANT=true, and a virtualbox will be set up.

To build locally we recommend using the included docker-compose setup. For a very simple setup installed locally, use `make provision`

Using Makefile, the following commands are available:

`make` : sets up and provisions virtual box

`make reload` : reloads box

`make halt` : stops virtual box

`make up` : starts box (no provisioning)

`make provision`: provision box

`make rebuild` : (re)build docker image (takes a while the first time)

`make run` : run/start koha container and link to running mysql container 

`make browser` : start firefox in box and test container (requires XQuartz on Mac and Cywin/X on Windows)

`make stop` : stop docker container

`make delete` : stop and remove container

## Koha development setup

######### KOHADEV SPECIFIC TARGETS #########

To setup a development setup, please provision with

`KOHAENV=dev make provision`

some extra make targets for development:

`make dump_kohadb` : Dumps Koha database

`restore_kohadb` : Restores Koha database

`delete_mysql_server` : Stops and removes mysql server

`delete_kohadb` : Deletes Koha database

`load_testdata` : Load optional test data

`reset_git` : Resets git by removing and doing new shallow clone

`reset_git_hard` : Resets git by removing and doing new shallow clone

`patch` : Patch Koha from bugzilla (e.g. PATCHES="16330 13799" make patch
