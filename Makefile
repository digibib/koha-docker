all: reload

reload: halt up

halt:
	vagrant halt

up:
	vagrant up

build:
	vagrant ssh -c 'sudo docker build -t digibib/koha /vagrant/ ' | tee build.log

run: 
	vagrant ssh -c 'sudo docker run --rm --name koha_docker -p 80:80 -p 8080:8080 -p 8081:8081 digibib/koha '

stop: 
	vagrant ssh -c 'sudo docker stop koha_docker'

delete: stop
	vagrant ssh -c 'sudo docker rm koha_docker'

nsenter:
	vagrant ssh -c 'sudo nsenter --target `sudo docker inspect --format="{{.State.Pid}}" koha_docker` --mount --uts --ipc --net --pid '

browser:
	vagrant ssh -c 'firefox "http://localhost:8081/" > firefox.log 2> firefox.err < /dev/null' &

clean:
	vagrant destroy --force
