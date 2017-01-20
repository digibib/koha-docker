.PHONY: all provision test clean

KOHAENV ?= build

ifdef VAGRANT
CMD=vagrant ssh $(SHIP)
KOHAPATH=/vagrant
HOST ?= 192.168.50.1
DOCKER_GW=$(HOST)
else
CMD=bash
KOHAPATH=$(shell pwd)
VAGRANT=true
HOST ?= localhost
DOCKER_GW=172.19.0.1
VAGRANT=false
endif

all: reload build run

reload: halt up provision

halt:
	@$(VAGRANT) && vagrant halt || true
	@$(VAGRANT) || sudo $(CMD) -c "cd $(KOHAPATH)/docker-compose && sudo docker-compose down" || true

up:                                              ##
	@$(VAGRANT) && vagrant up || true
	@$(VAGRANT) || sudo $(CMD) -c "cd $(KOHAPATH)/docker-compose && sudo docker-compose up -d" || true

shell_provision:					## Run ONLY shell provisioners
	@$(VAGRANT) && vagrant provision --provision-with shell || true
	-@$(VAGRANT) || ./provision.sh $(KOHAENV) $(KOHAPATH)

provision:  shell_provision   	## Full provision

wait_until_ready:
	@echo "=======    wait until ready    ======\n"
	$(CMD) -c 'sudo docker exec -t koha_build ./wait_until_ready.py'

ifeq ($(KOHAENV),build)
COMPOSE=cd $(KOHAPATH)/docker-compose && source docker-compose.env && KOHAPATH=$(KOHAPATH) docker-compose -f common.yml
else
COMPOSE=cd $(KOHAPATH)/docker-compose && source docker-compose.env && KOHAPATH=$(KOHAPATH) docker-compose -f common.yml -f $(KOHAENV).yml
endif
rebuild:
	@echo "======= FORCE RECREATING koha ======\n"
	$(CMD) -c "$(COMPOSE) stop koha && true &&\
	$(COMPOSE) rm -f koha || true &&\
	$(COMPOSE) build koha &&\
	$(COMPOSE) up --force-recreate --no-deps -d koha"

build_debianfiles:
	@echo "======= BUILDING KOHA CONTAINER FROM LOCAL DEBIANFILES ======\n"
	$(CMD) -c 'sudo docker build --build-arg KOHA_BUILD=$(KOHA_BUILD) \
	-f $(KOHAPATH)/Dockerfile.debianfiles -t digibib/koha $(KOHAPATH)'

run: delete
	$(CMD) -c "$(COMPOSE) up -d koha"

run_manual: delete
	@echo "======= MANUAL RUN OF koha CONTAINER ======\n"
	$(CMD) -c "$(COMPOSE) run --rm --entrypoint bash --service-ports koha"

stop:
	$(CMD) -c "$(COMPOSE) stop koha || true"

delete: stop
	$(CMD) -c "$(COMPOSE) rm -fv koha || true"

logs:
	$(CMD) -c "$(COMPOSE) logs koha"

logs-nocolor:
	$(CMD) -c "$(COMPOSE) logs --no-color koha"

logs-f:
	$(CMD) -c "$(COMPOSE) logs -f koha"

logs-f-nocolor:
	$(CMD) -c "$(COMPOSE) logs -f --no-color koha"

browser:
	$(CMD) -c 'firefox "http://localhost:8081/" > firefox.log 2> firefox.err < /dev/null' &

test: wait_until_ready
	@echo "======= TESTING KOHA CONTAINER ======\n"

login: # needs EMAIL, PASSWORD, USERNAME
	@ $(CMD) -c 'sudo docker login --email=$(EMAIL) --username=$(USERNAME) --password=$(PASSWORD)'

tag = "$(shell git rev-parse HEAD)"

tag:
	$(CMD) -c 'sudo docker tag -f digibib/koha digibib/koha:$(tag)'

push:
	@echo "======= PUSHING KOHA CONTAINER ======\n"
	$(CMD) -c 'sudo docker push digibib/koha'

docker_cleanup:						## Clean up unused docker containers and images
	@echo "cleaning up unused containers, images and volumes"
	$(CMD) -c 'sudo docker rmi $$(sudo docker images -aq -f dangling=true) 2> /dev/null || true'
	$(CMD) -c 'sudo docker volume rm $$(sudo docker volume ls -q -f=dangling=true) 2> /dev/null || true'

######### KOHADEV SPECIFIC TARGETS #########

dump_kohadb:		## Dumps Koha database
	@echo "======= DUMPING KOHA DATABASE ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \"mysqldump --all-databases > /tmp/kohadump.sql\""

restore_kohadb:	## Restores Koha database
	@echo "======= RESTORING KOHA DATABASE ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \"mysql < /tmp/kohadump.sql\""

delete_mysql_server:		## Stops and removes mysql server
	@echo "======= STOPPING MYSQL SERVER ======\n"
	$(CMD) -c "$(COMPOSE) stop koha_mysql"
	$(CMD) -c "$(COMPOSE) rm -f koha_mysql"

delete_kohadb:	stop delete_mysql_server		## Deletes Koha database
	@echo "======= DELETING KOHA DATABASE ======\n"
	$(CMD) -c "$(COMPOSE) rm -f koha_mysql_data"

load_testdata:	## Load optional test data
	@echo "======= LOADING KOHA TESTDATA ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \
	\"for file in /kohadev/kohaclone/installer/data/mysql/en/optional/*.sql; do \
	koha-mysql name < \$$file ; \
	done;\""

reset_git:			## Resets git by removing and doing new shallow clone
	@echo "======= RELOADING CLEAN KOHA MASTER ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \"cd /kohadev/kohaclone && \
		git clean -xdf && git am --abort || true && git reset --hard && \
		git checkout master && git branch -D sandbox || true\""

reset_git_hard:	## Resets git by removing and doing new shallow clone
	@echo "======= RELOADING CLEAN KOHA MASTER ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \"cd /kohadev && rm -rf kohaclone && git clone --depth 1 \$$KOHA_REPO kohaclone\""

patch:					## needs PATCHES
	@echo "======= PATCHING KOHADEV CONTAINER ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \"cd /kohadev/kohaclone && \
	(git checkout -b sandbox || true) && \
	for patch in $(PATCHES) ; do \
		yes | git bz apply \$$patch ; \
	done\""
