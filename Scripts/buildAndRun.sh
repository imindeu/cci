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
#
# it also needs (in strict order and count):
# - circleCiTokens=token01,token02,token03
# for
# - circleCiProjects=CIProjectName01,CIProjectName02,CIProjectName03
# to run slack command on CircleCI
  docker run -it \
  -e port="8080" \
  -e slackToken="SLACKTOKEN" \
  -e circleCiTokens="CIRCLECITOKENS" \
  -e circleCiVcs="github" \
  -e circleCiProjects="4dmotion-ios@cci@4dmotion-android" \
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
# see slack.sh
