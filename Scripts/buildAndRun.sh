#!/bin/sh

# build
#  - add 'cci' tag
#  - path: . (current directory)
docker build -t cci .

if [ $? -eq 0 ]
then
  echo "Successfull build"

# sound effect after build
  echo '\007'
  
# run
#  - set environment variabes with '-e'
#    - set debugMode=true for debug messages
#  - port: localhost 8080 -> cci 8081
#  - docker image tag: cci
  docker run -it \
  -e port="8080" \
  -e slackToken="SLACKTOKEN" \
  -e circleCiTokens="CIRCLECITOKENS" \
  -e circleCiVcs="github" \
  -e circleCiProjects="4dmotion-ios@cci" \
  -e circleCiCompany="CIRCLECICOMPANY" \
  -e githubSecret="GITHUBSECRET" \
  -e githubAppId="GITHUBAPPID" \
  -e githubPrivateKey="GITHUBPRIVATEKEY" \
  -e youtrackURL="YOUTRACKURL" \
  -e youtrackToken="YOUTRACKTOKEN" \
  -e debugMode="true" \
  -p 8080:8081 \
  cci
else
  echo "Build has failed"
# sound effect after build
  echo '\007'

fi


# sample call:
# curl -d 'token=SLACKTOKEN&team_id=team_id&team_domain=team_domain&channel_id=channel_id&channel_name=4dmotion-ios&user_id=user_id&user_name=user_name&command=deploy&text=deploy fourd alpha emails:gab.horv@gmail.com unofficial_release:true customChangelog:"Test changelog with spaces" feature/4DM-5808-Update-deploy-from-custom-branch&response_url=http://testresponseurl.com:1234&trigger_id=trigger_id' -X POST http://localhost:8080/slackCommand
