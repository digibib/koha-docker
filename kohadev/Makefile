.PHONY: all test clean

all: reload build run

reload: halt up provision

halt:
	vagrant halt

up:
	vagrant up

provision:
	vagrant provision

upgrade:
	vagrant ssh -c 'sudo docker pull digibib/kohadev'

build:
	@echo "======= BUILDING KOHADEV CONTAINER ======\n"
	vagrant ssh -c 'sudo docker build -t digibib/kohadev /vagrant/kohadev'

stop: 
	@echo "======= STOPPING KOHADEV CONTAINER ======\n"
	vagrant ssh -c 'sudo docker stop kohadev_docker' || true

delete: stop
	@echo "======= DELETING KOHADEV CONTAINER ======\n"
	vagrant ssh -c 'sudo docker rm kohadev_docker' || true

run: delete			## start kohadev container - args: AUTHOR_NAME, AUTHOR_EMAIL, BUGZ_USER, BUGZ_PASS
	@echo "======= RUNNING KOHADEV CONTAINER WITH LOCAL MYSQL ======\n"
	vagrant ssh -c 'sudo docker run -d --name kohadev_docker \
	-p 80:80 -p 6001:6001 -p 8080:8080 -p 8081:8081 \
	-e AUTHOR_NAME=$(AUTHOR_NAME) \
	-e AUTHOR_EMAIL=$(AUTHOR_EMAIL) \
	-e BUGZ_USER=$(BUGZ_USER) \
	-e BUGZ_PASS=$(BUGZ_PASS) \
	-t digibib/kohadev' || echo "kohadev_docker container already running, please 'make delete' first"

reset_git:			## Resets git by removing and doing new shallow clone
	@echo "======= RELOADING CLEAN KOHA MASTER ======\n"
	vagrant ssh -c "sudo docker exec kohadev_docker bash -c 'cd /kohadev && rm -rf kohaclone && git clone --depth 1 \$$KOHA_REPO kohaclone'"

patch:					## needs PATCHES
	@echo "======= PATCHING KOHADEV CONTAINER ======\n"
	@vagrant ssh -c 'sudo docker exec -t kohadev_docker /bin/bash -c "cd /kohadev/kohaclone && \
	(git checkout -b sandbox || true) && \
	for patch in $(PATCHES) ; do \
		yes | git bz apply \$$patch ; \
	done"'

logs:
	vagrant ssh -c 'sudo docker logs kohadev_docker'

logs-f:
	vagrant ssh -c 'sudo docker logs -f kohadev_docker'

browser:
	vagrant ssh -c 'firefox "http://localhost:8081/" > firefox.log 2> firefox.err < /dev/null' &

wait_until_ready:
	@echo "======= WAIT UNTIL READY ======\n"
	vagrant ssh -c 'sudo docker exec -t kohadev_docker ./wait_until_ready.py'

test: wait_until_ready
	@echo "======= TESTING KOHA CONTAINER SANITY ======\n"

clean:
	vagrant destroy --force

login: # needs EMAIL, PASSWORD, USERNAME
	@ vagrant ssh -c 'sudo docker login --email=$(EMAIL) --username=$(USERNAME) --password=$(PASSWORD)'

tag = "$(shell git rev-parse HEAD)"
push:
	@echo "======= PUSHING KOHA CONTAINER ======\n"
	vagrant ssh -c 'sudo docker tag digibib/kohadev digibib/kohadev:$(tag)'
	vagrant ssh -c 'sudo docker push digibib/kohadev'

