Koha Docker Container
===

This project builds a [Docker](https://www.docker.com/) image containg an installation of the library system [Koha](http://koha-community.org/). 

If you don't want to build the Docker image yourself we automatically build and push new versions of the image to [Docker Hub Registry](https://registry.hub.docker.com/u/digibib/koha/) on every push to [this GitHub repository](https://github.com/digibib/koha-salt-docker). New images are given tags that correspond to the git head revisions in the git repo. See the section [Using the Koha Docker image](#using-the-Koha-docker-image) for more information.

As Docker is only supported natively on Linux, we build and test our Docker image inside a [VirtualBox](https://www.virtualbox.org/) build machine. To make it easier to work with VirtualBox we use [Vagrant](https://www.vagrantup.com) for provisioning the virtual build machine. If you want to build the image yourself you need to [install Virtualbox](https://www.virtualbox.org/wiki/Downloads) and [Vagrant](https://www.virtualbox.org/wiki/Downloads) first (on Windows you also need some 'nix tools through e g Cygwin).

The image is built from a [Dockerfile](./Dockerfile) which also invokes [Salt](http://docs.saltstack.com/) states. (The use of Salt preceeded our use of Docker, which is why it is still around.) 

The Docker image produced uses currently released [Debian packages of Koha](http://wiki.koha-community.org/wiki/Koha_on_Debian). 

There is also a Docker setup for a Koha development version from git available in the subfolder `kohadev`. Please read the README in this folder for further instructions.

The image will on startup go through the steps of the Koha Webinstaller accepting default settings, and choosing MARC-flavour: MARC21.

## Using the Koha Docker image

This section assumes [some](https://www.docker.com/whatisdocker/) [understanding](https://docs.docker.com/introduction/understanding-docker/) [of Docker](http://www.dockerbook.com/), and a machine (virtual or physical) capable of running Docker.

### Download image from Docker Hub Registry

```docker pull digibib/koha:[tag/revision]```

The `tag/revision` should correspond to the git revisions in this git repository.

### Starting a Koha Docker container

<pre>docker run -d --name koha_docker \
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

[TBW]

### Logs

Log entries from a number of logs will be concatenated into standard out and can be seen using:
```docker logs koha_docker```

The logs tailed to standard out: 
<pre>  /var/log/apache2/access.log
  /var/log/koha/${KOHA_INSTANCE}/intranet*.log
  /var/log/koha/${KOHA_INSTANCE}/opac*.log
  /var/log/koha/${KOHA_INSTANCE}/zebra*.log
  /var/log/apache2/other_vhosts_access.log
  /var/log/koha/${KOHA_INSTANCE}/sip*.log
</pre>

## Installing virtual build machine

If you want to build the image yourself you need to install and set up a virtual build machine.

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

Using Makefile, the following commands are available:

`make` : sets up and provisions virtual box

`make reload` : reloads box

`make halt` : stops virtual box

`make up` : starts box (no provisioning)

`make provision`: provision box

`make build` : build docker image (takes a while the first time)

`make mysql_start` : setup a mysql container

`make mysql_stop` : stop and remove a running mysql container

`make run` : run/start koha container and link to running mysql container 

`make browser` : start firefox in box and test container (requires XQuartz on Mac and Cywin/X on Windows)

`make stop` : stop docker container

`make delete` : stop and remove container

`make nsenter` : open shell inside container

All docker relevant files are in /vagrant/koha, so building an image manually inside the vagrant box (do `vagrant ssh` first) is done by
```sudo docker build -t kohaimage /vagrant/koha``` 


