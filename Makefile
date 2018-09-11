build-swift:
	swift build --product Run --configuration release

run-swift:
	circleciTokens=${CIRCLECITOKENS}; slackToken=${SLACKTOKEN}; port=${PORT};vcs=${VCS};projects=${PROJECTS}; company=${COMPANY}; export circleciToken slackToken port vcs projects company; .build/release/Run

build-image: 
	docker build -t cci .

run-app:
	${SUDO} docker run --name cci -i -d -t -p 8081:8081 -e circleciTokens=${CIRCLECITOKENS} -e slackToken=${SLACKTOKEN} -e port=${PORT} -e vcs=${VCS} -e projects=${PROJECTS} -e company=${COMPANY}  --restart unless-stopped cci

stop-app:
	${SUDO} docker stop cci

remove-app:
	${SUDO} docker rm cci

remove-image: 
	${SUDO} docker rmi cci

connect:
	${SUDO} docker exec -it cci /bin/bash

logs:
	${SUDO} docker logs cci

export-image:
	${SUDO} docker save -o cci-image cci

import-image:
	${SUDO} docker load -i cci-image

restart: stop-app remove-app remove-image import-image run-app

scp:
	scp cci-image Makefile ${SSH_USER}@${SSH_HOST}:${SSH_PATH}

deploy:
	ssh ${SSH_USER}@${SSH_HOST} "cd ${SSH_PATH} && make restart CIRCLECITOKENS=${CIRCLECITOKENS} SLACKTOKEN=${SLACKTOKEN} PORT=${PORT} VCS=${VCS} PROJECTS=${PROJECTS} COMPANY=${COMPANY} SUDO=${SUDO}"

build-export-scp-deploy: build-image export-image scp deploy remove-image
	rm cci-image

.PHONY: build-swift run-swift build-image run-app stop-app remove-app connect logs export-image restart scp deploy build-export-scp-deploy

