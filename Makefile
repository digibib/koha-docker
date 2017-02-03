.PHONY: all provision test clean help

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

ifeq ($(KOHAENV),build)
COMPOSE=cd $(KOHAPATH)/docker-compose && source docker-compose.env && KOHAPATH=$(KOHAPATH) docker-compose -f common.yml
else
COMPOSE=cd $(KOHAPATH)/docker-compose && source docker-compose.env && KOHAPATH=$(KOHAPATH) docker-compose -f common.yml -f $(KOHAENV).yml
endif

help:				## Show this help.
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

all: halt provision		## Reloads and runs full provisioning

halt:				## Takes down all docker containers and network
	@$(VAGRANT) && vagrant halt || true
	@$(VAGRANT) || sudo $(CMD) -c "$(COMPOSE) down" || true

provision:			## Full provision - sets up docker and compose and all docker containers
	@$(VAGRANT) && vagrant provision --provision-with shell || true
	-@$(VAGRANT) || ./provision.sh $(KOHAENV) $(KOHAPATH)

up:				## Sets up all docker containers
	@$(VAGRANT) && vagrant up || true
	@$(VAGRANT) || sudo $(CMD) -c "$(COMPOSE) up -d" || true

wait_until_ready:
	@echo "=======    wait until ready    ======\n"
	$(CMD) -c 'docker exec -it koha_$(KOHAENV) ./wait_until_ready.py'

rebuild:			## Build and start Koha
	@echo "======= FORCE RECREATING koha ======\n"
	$(CMD) -c "$(COMPOSE) stop koha && true &&\
	$(COMPOSE) rm -f koha || true &&\
	$(COMPOSE) build koha &&\
	$(COMPOSE) up --force-recreate --no-deps -d koha"

build_debianfiles:		## Build from local debianfiles (koha-patched/debian)
	@echo "======= BUILDING KOHA CONTAINER FROM LOCAL DEBIANFILES ======\n"
	$(CMD) -c 'sudo docker build --build-arg KOHA_BUILD=$(KOHA_BUILD) \
	-f $(KOHAPATH)/Dockerfile.debianfiles -t digibib/koha $(KOHAPATH)'

run: delete 			## Start Koha container
	$(CMD) -c "$(COMPOSE) up -d koha"

stop: 				## Stop Koha container
	$(CMD) -c "$(COMPOSE) stop koha || true"

delete: stop 			## Delete Koha container
	$(CMD) -c "$(COMPOSE) rm -fv koha || true"

######### DEBUGGING TARGETS #########

run_manual: delete 		## Manually start a Koha container without entrypoint
	@echo "======= MANUAL RUN OF koha CONTAINER ======\n"
	$(CMD) -c "$(COMPOSE) run --rm --entrypoint bash --service-ports koha"

logs:				## Show Koha logs
	$(CMD) -c "$(COMPOSE) logs koha"

logs-nocolor:			## Show Koha logs without ansi colours
	$(CMD) -c "$(COMPOSE) logs --no-color koha"

logs-f:				## Tail and follow Koha logs
	$(CMD) -c "$(COMPOSE) logs -f koha"

logs-f-nocolor:			## Tail and follow Koha logs without ansi colours
	$(CMD) -c "$(COMPOSE) logs -f --no-color koha"

browser:			## Open Koha intra in firefox 
	$(CMD) -c 'firefox "http://localhost:8081/" > firefox.log 2> firefox.err < /dev/null' &

test: wait_until_ready 		## Run status checks on Koha container
	@echo "======= TESTING KOHA CONTAINER ======\n"

docker_cleanup:			## Clean up unused docker containers and images
	@echo "cleaning up unused containers, images and volumes"
	$(CMD) -c 'sudo docker system prune -f || true'

######### KOHADEV SPECIFIC TARGETS #########

dump_kohadb:			## Dumps Koha database
	@echo "======= DUMPING KOHA DATABASE ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \"mysqldump --all-databases > /tmp/kohadump.sql\""

restore_kohadb:			## Restores Koha database
	@echo "======= RESTORING KOHA DATABASE ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \"mysql < /tmp/kohadump.sql\""

delete_mysql_server:		## Stops and removes mysql server
	@echo "======= STOPPING MYSQL SERVER ======\n"
	$(CMD) -c "$(COMPOSE) stop koha_mysql"
	$(CMD) -c "$(COMPOSE) rm -f koha_mysql"

delete_kohadb: stop delete_mysql_server		## Deletes Koha database
	@echo "======= DELETING KOHA DATABASE ======\n"
	$(CMD) -c "$(COMPOSE) volume rm -f koha_mysql_data"

load_testdata:			## Load optional test data
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

reset_git_hard:			## Resets git by removing and doing new shallow clone
	@echo "======= RELOADING CLEAN KOHA MASTER ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \"cd /kohadev && rm -rf kohaclone && git clone --depth 1 \$$KOHA_REPO kohaclone\""

patch:				## Apply patches on koha dev, needs PATCHES="<bugid> <bugid> <bugid>"
	@echo "======= PATCHING KOHADEV CONTAINER ======\n"
	$(CMD) -c "$(COMPOSE) exec koha bash -c \"cd /kohadev/kohaclone && \
	(git checkout -b sandbox || true) && \
	for patch in $(PATCHES) ; do \
		yes | git bz apply \$$patch ; \
	done\""

######### DOCKER HUB SPECIFIC TARGETS #########

login: 				## Log in to docker hub, needs PASSWORD and USERNAME
	@ $(CMD) -c 'sudo docker login --username=$(USERNAME) --password=$(PASSWORD)'

tag = "$(shell git rev-parse HEAD)"

tag:				## Tag image from current GITREF
	$(CMD) -c 'sudo docker tag -f digibib/koha digibib/koha:$(tag)'

push:				## Push current image to docker hub
	@echo "======= PUSHING KOHA CONTAINER ======\n"
	$(CMD) -c 'sudo docker push digibib/koha:$(tag)'
