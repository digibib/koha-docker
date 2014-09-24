Bootstrapping salt master / minons
======

 This How-To explains how to "automate" install of Salt Master, Salt Minion and keys
 For proper functionality, installation of v2014.7 is recommended

## Install of salt master

(stable):
```ssh -t sudouser@master 'wget -O- --quiet https://bootstrap.saltstack.com | \
   sudo sh -s -- -M'```

(from git: v2014.7):
NB: If remote server has firewall preventing git port, it can be circumvented by adding the
`-g [git repo for salt]` flag to use https instead

```ssh -t sudouser@master 'wget -O- --quiet https://bootstrap.saltstack.com | \
   sudo sh -s -- -g https://github.com/saltstack/salt.git -M -N -P git 2014.7'```

Example: `ssh -t vagrant@192.168.50.12 'wget -O- --quiet https://bootstrap.saltstack.com | sudo sh -s -- -M -N'`

or: `vagrant ssh ls.db -c 'wget -O- --quiet https://bootstrap.saltstack.com | sudo sh -s -- -M'`

## Install salt minion

1) install minion

```ssh -t sudouser@minion 'wget -O- --quiet https://bootstrap.saltstack.com | sudo sh -'```

Example: `ssh -t vagrant@192.168.50.21 'wget -O- --quiet https://bootstrap.saltstack.com | sudo sh -'`

or: `vagrant ssh ls.devops -c 'wget -O- --quiet https://bootstrap.saltstack.com | sudo sh -'`

2) add master to minion

add_master.py:

```cat add_master.py | ssh -t sudouser@minion 'MASTER_IP=[add master ip here] python --'```

Example: `cat add_master.py | ssh -t vagrant@192.168.50.21 'MASTER_IP=192.168.50.12 python--'`

or: `cat add_master.py | vagrant ssh ls.devops -c 'MASTER_IP=192.168.50.12 python --'`

3) remove any existing minion_master key

```ssh -t sudouser@minion 'sudo rm -rf /etc/salt/pki/minion/minion_master.pub'```

Example: `ssh -t vagrant@192.168.50.21 'sudo rm -rf /etc/salt/pki/minion/minion_master.pub'`

or: `vagrant ssh ls.devops -c 'sudo rm -rf /etc/salt/pki/minion/minion_master.pub'`

4) restart salt-minion

```ssh -t sudouser@minion 'sudo service salt-minion restart'```

Example: `ssh -t vagrant@192.168.50.21 'sudo service salt-minion restart'`

or: `vagrant ssh ls.devops -c 'sudo service salt-minion restart'`

## Accept minion keys on master

```ssh -t suduser@master 'sudo salt-key --accept-all --yes'```

Example: `ssh -t vagrant@192.168.50.12 'sudo salt-key --accept-all --yes'`

or: `vagrant ssh ls.db -c 'sudo salt-key --accept-all --yes'`

## Test setup

```ssh -t sudouser@master 'sudo salt "*" test.ping'```

Example: `ssh -t vagrant@192.168.50.12  -c 'sudo salt "*" test.ping'`

or: `vagrant ssh ls.db -c 'sudo salt "*" test.ping'`

### Example Master config

1) a very basic config :
/etc/salt/master:
```
fileserver_backend:
  - roots
  - git

file_roots:
  base:
    - /srv/salt
pillar_roots:
  base:
    - /srv/pillar
```

2) create master folder structure:
```sudo mkdir -p /srv/{salt,pillar}```

3) Setup top.sls and salt files