all: reload

reload: halt up

halt:
	@vagrant halt

up:
	@vagrant up

mysql: create_data_volume mysql_start

# Data volume container for mysql - for persistent data. Create new if not existing
create_data_volume:
	@echo "======= CREATING MYSQL DATA VOLUME CONTAINER ======\n"
	@vagrant ssh -c 'sudo docker inspect mysql_data || docker run -i -t -name mysql_data -v /var/lib/mysql busybox /bin/sh'

mysql_start: mysql_stop
	@vagrant ssh -c 'sudo docker run -d \
  --name koha_docker_mysql \
  -p 3306:3306 \
  --volumes-from mysql_data \
  -e MYSQL_ROOT_PASSWORD=secret \
  -e MYSQL_USER=admin \
  -e MYSQL_PASSWORD=secret \
  -e MYSQL_DATABASE=koha_name \
  -t mysql:5.6 \
  mysqld --datadir=/var/lib/mysql --user=mysql --max_allowed_packet=64M --wait_timeout=6000 --bind-address=0.0.0.0'

mysql_stop:
	@echo "======= RESTARTING MYSQL CONTAINER ======\n"
	@vagrant ssh -c '(sudo docker stop koha_docker_mysql && sudo docker rm koha_docker_mysql) || true'

build:
	@echo "======= BUILDING KOHA CONTAINER ======\n"
	@vagrant ssh -c 'sudo docker build -t digibib/koha /vagrant ' | tee build.log

# start koha with link to mysql container
run: mysql
	@echo "======= RUNNING KOHA CONTAINER ======\n"
	@vagrant ssh -c 'sudo docker rm koha_docker || \
	sudo docker run --link koha_docker_mysql:db --volumes-from mysql_data -d --name koha_docker \
	-p 80:80 -p 8080:8080 -p 8081:8081 digibib/koha '

stop: 
	@echo "======= STOPPING KOHA CONTAINER ======\n"
	@vagrant ssh -c 'sudo docker stop koha_docker'

delete: stop
	@vagrant ssh -c 'sudo docker rm koha_docker'

nsenter:
	@vagrant ssh -c 'sudo nsenter --target `sudo docker inspect --format="{{.State.Pid}}" koha_docker` --mount --uts --ipc --net --pid '

browser:
	@vagrant ssh -c 'firefox "http://localhost:8081/" > firefox.log 2> firefox.err < /dev/null' &

clean:
	@vagrant destroy --force
