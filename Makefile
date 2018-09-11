# build/run locally on macos

build-swift:
	swift build --product Run --configuration release

run-swift:
	@circleciTokens=${CIRCLECITOKENS}; slackToken=${SLACKTOKEN}; port=${PORT};vcs=${VCS};projects=${PROJECTS}; company=${COMPANY}; export circleciToken slackToken port vcs projects company; .build/release/Run


# docker image

build-image: 
	docker build -t cci .

remove-image: 
	${SUDO} docker rmi cci

export-image:
	docker save -o cci-image cci

import-image:
	${SUDO} docker load -i cci-image


# docker container

run-app:
	@echo "Container starting..."
	@${SUDO} docker run --name cci -i -d -t -p ${PORT}:${PORT} -e circleciTokens=${CIRCLECITOKENS} -e slackToken=${SLACKTOKEN} -e port=${PORT} -e vcs=${VCS} -e projects=${PROJECTS} -e company=${COMPANY}  --restart unless-stopped cci
	@echo "Started."

stop-app:
	${SUDO} docker stop cci

remove-app:
	${SUDO} docker rm cci

connect:
	${SUDO} docker exec -it cci /bin/bash

logs:
	${SUDO} docker logs cci


# deploy

clean-deploy:
	@echo "Cleaning up deploy..."
	@rm cci-image && cp Makefile Makefile-`date +"%s"`
	@echo "Cleaned up."

restart: stop-app remove-app remove-image import-image run-app clean-deploy

scp:
	@echo "Copying image to remote host..."
	@scp -q cci-image Makefile ${SSH_USER}@${SSH_HOST}:${SSH_PATH}
	@echo "Copied."

deploy:
	@echo "Starting remote deploy..."
	@ssh ${SSH_USER}@${SSH_HOST} "cd ${SSH_PATH} && make restart CIRCLECITOKENS=${CIRCLECITOKENS} SLACKTOKEN=${SLACKTOKEN} PORT=${PORT} VCS=${VCS} PROJECTS=${PROJECTS} COMPANY=${COMPANY} SUDO=${SUDO}"
	@echo "Deployed."

build-export-scp-deploy: build-image export-image scp deploy

.PHONY: build-swift \
	run-swift \
	build-image \
	remove-image \
	export-image \
	import-image \
	run-app \
	stop-app \
	remove-app \
	connect \
	logs \
	delete-image \
	restart \
	scp \
	deploy \
	build-export-scp-deploy
