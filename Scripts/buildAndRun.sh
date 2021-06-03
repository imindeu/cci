#!/bin/sh

cd "$(dirname "$0")/.."

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
  -e circleCiTokens="token1@token2" \
  -e circleCiPersonalApiToken="personalToken" \
  -e circleCiVcs="github" \
  -e circleCiProjects="4dmotion-ios@cci" \
  -e circleCiCompany="imindeu" \
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
# see slack.sh
