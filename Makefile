# checks
ifndef PORT
  $(error PORT is not set)
endif
ifndef SLACKTOKEN
  $(error SLACKTOKEN is not set)
endif
ifndef CIRCLECITOKENS
  $(error CIRCLECITOKENS is not set)
endif
ifndef CIRCLECIVCS
  $(error CIRCLECIVCS is not set)
endif
ifndef CIRCLECIPROJECTS
  $(error CIRCLECIPROJECTS is not set)
endif
ifndef CIRCLECICOMPANY
  $(error CIRCLECICOMPANY is not set)
endif
ifndef YOUTRACKTOKEN
  $(error YOUTRACKTOKEN is not set)
endif
ifndef YOUTRACKURL
  $(error YOUTRACKURL is not set)
endif
ifndef GITHUBSECRET
  $(error GITHUBSECRET is not set)
endif
ifndef GITHUBAPPID
  $(error GITHUBAPPID is not set)
endif
ifndef GITHUBPRIVATEKEY
  $(error GITHUBPRIVATEKEY is not set)
endif

# create tests for linux
imports = @testable import APIConnectTests;\
	  @testable import APIServiceTests;\
	  @testable import AppTests

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
	@echo "Building container..."
	docker build -t cci .
	@echo "Built."

hasImage = $$(${SUDO} docker images | awk '{print $1}' | grep "cci" | wc -l | tr -d '[:space:]')
remove-image: 
	@if [ $(hasImage) -eq 1 ]; then \
	  echo "Removing image..."; \
	  ${SUDO} docker rmi cci; \
	  echo "Removed."; \
	  else echo "No image, skipping remove ($(hasImage))"; \
	  fi

export-image:
	docker save -o cci-image cci

import-image:
	@echo "Importing image..."
	${SUDO} docker load -i cci-image


# docker container

run-app:
	@echo "Container starting..."
	@${SUDO} docker run --name cci -i -d -t -p ${PORT}:8081 \
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

hasRunningContainer = $$(${SUDO} docker ps | awk '{print $2}' | grep "cci" | wc -l | tr -d '[:space:]')
stop-app:
	@if [ $(hasRunningContainer) -eq 1 ]; then \
	  echo "Stopping container..."; \
	  ${SUDO} docker stop cci; \
	  echo "Stopped."; \
	  else echo "No running container, skipping stop ($(hasRunningContainer))"; \
	  fi

hasContainer = $$(${SUDO} docker ps -a | awk '{print $2}' | grep "cci" | wc -l | tr -d '[:space:]')
remove-app:
	@if [ $(hasContainer) -eq 1 ]; then \
	  echo "Removing container..."; \
	  ${SUDO} docker rm cci; \
	  echo "Removed."; \
	  else echo "No container, skipping remove ($(hasContainer))"; fi

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

build-local-deploy: stop-app remove-app remove-image build-image run-app

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
	build-export-scp-deploy \
	build-local-deploy

