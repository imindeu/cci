# create tests for linux

imports = @testable import APIConnectTests; @testable import AppTests

linux-main:
	sourcery \
	  --sources ./Tests/ \
	  --templates ./.sourcery-templates/LinuxMain.stencil \
	  --output ./Tests \
	  --args testimports='${imports}' \
	  && mv ./Tests/LinuxMain.generated.swift ./Tests/LinuxMain.swift

# build/run locally on macos

build-swift:
	swift build --product Run --configuration release

run-swift:
	@port=${PORT}; \
	  slackToken=${SLACKTOKEN}; \
	  circleCiTokens=${CIRCLECITOKENS}; \
	  circleCiVcs=${CIRCLECIVCS}; \
	  circleCiProjects=${CIRCLECIPROJECTS}; \
	  circleCiCompany=${CIRCLECICOMPANY}; \
	  githubSecret=${GITHUBSECRET}; \
	  githubAppId=${GITHUBAPPID}; \
	  githubPrivateKey="${GITHUBPRIVATEKEY}"; \
	  youtrackURL=${YOUTRACKURL}; \
	  youtrackToken=${YOUTRACKTOKEN}; \
	  export port slackToken circleCiToken circleCiVcs circleCiProjects circleCiCompany githubSecret githubAppId githubPrivateKey youtrackURL youtrackToken; \
	  .build/release/Run


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
	@${SUDO} docker run --name cci -i -d -t -p ${PORT}:${PORT} \
	  -e port=${PORT} \
	  -e slackToken=${SLACKTOKEN} \
	  -e circleCiTokens=${CIRCLECITOKENS} \
	  -e circleCiVcs=${CIRCLECIVCS} \
	  -e circleCiProjects=${CIRCLECIPROJECTS} \
	  -e circleCiCompany=${CIRCLECICOMPANY}  \
	  -e githubSecret=${GITHUBSECRET} \
	  -e githubAppId=${GITHUBAPPID} \
	  -e githubPrivateKey="${GITHUBPRIVATEKEY}" \
	  -e youtrackURL=${YOUTRACKURL} \
	  -e youtrackToken=${YOUTRACKTOKEN} \
	  --restart unless-stopped cci
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
	@ssh ${SSH_USER}@${SSH_HOST} "\
	  cd ${SSH_PATH} \
	  && make restart PORT=${PORT} \
	  SLACKTOKEN=${SLACKTOKEN} \
	  CIRCLECITOKENS=${CIRCLECITOKENS} \
	  CIRCLECIVCS=${CIRCLECIVCS} \
	  CIRCLECIPROJECTS=${CIRCLECIPROJECTS} \
	  CIRCLECICOMPANY=${CIRCLECICOMPANY} \
	  GITHUBSECRET=${GITHUBSECRET} \
	  GITHUBAPPID=${GITHUBAPPID} \
	  GITHUBPRIVATEKEY=\"${GITHUBPRIVATEKEY}\" \
	  YOUTRACKURL=${YOUTRACKURL} \
	  YOUTRACKTOKEN=${YOUTRACKTOKEN} \
	  SUDO=${SUDO}"
	@echo "Deployed."

build-export-scp-deploy: build-image export-image scp deploy

.PHONY: sourcery \
        build-swift \
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
	clean-deploy \
	restart \
	scp \
	deploy \
	build-export-scp-deploy
