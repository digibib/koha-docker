all: reload provision

reload: halt up

halt:
	vagrant halt

up:
	vagrant up

# should run vagrant provison but that would take longer as it reinstalls(?) salt
provision:
	vagrant ssh -c 'sudo salt-call --log-level debug --local state.highstate'

build:
	vagrant ssh -c 'sudo docker build -t digibib/koha /vagrant/ '

run: 
	vagrant ssh -c 'sudo docker run --rm --name koha_docker digibib/koha '

stop: 
	vagrant ssh -c 'sudo docker stop koha_docker'

delete: stop
	vagrant ssh -c 'sudo docker rm koha_docker'

nsenter:
	vagrant ssh -c 'sudo nsenter --target `sudo docker inspect --format="{{.State.Pid}}" koha_docker` --mount --uts --ipc --net --pid '

clean:
	vagrant destroy --force
