all: reload

reload: halt up

halt:
	vagrant halt

up:
	vagrant up

mysql_start:
	vagrant ssh -c 'sudo docker run -d \
	--name koha_docker_mysql \
	-p 3306:3306 \
	-v /var/lib/koha_docker_mysql:/var/lib/mysql \
	-e MYSQL_ROOT_PASSWORD=secret \
	-e MYSQL_USER=admin \
	-e MYSQL_PASS=secret \
	-e MYSQL_DATABASE=koha_name \
	-t mysql:5.6 \
	mysqld --datadir=/var/lib/mysql --user=mysql --max_allowed_packet=64M --wait_timeout=6000 --bind-address=0.0.0.0'

mysql_stop:
	vagrant ssh -c 'sudo docker stop koha_mysql_docker && sudo docker rm koha_mysql_docker'

build:
	vagrant ssh -c 'sudo docker build -t digibib/koha /vagrant/koha ' | tee build.log

# start koha with link to mysql container
run: 
	vagrant ssh -c 'sudo docker run --link koha_docker_mysql:db --rm --name koha_docker -p 80:80 -p 8080:8080 -p 8081:8081 digibib/koha '

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
