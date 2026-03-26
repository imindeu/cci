#!/bin/sh

cd "$(dirname "$0")/.."

# build
#  - add 'cci' tag
#  - path: . (current directory)
docker build -t cci -f Dockerfile.local .

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
  GITHUBPRIVATEKEY="-----BEGIN RSA PRIVATE KEY-----\\nMIIEpAIBAAKCAQEAtEk1vL2EehyRW4kPwBZcb8Ke7MOpItJ3fUoj8QcA1YprwlZj\\nyZE1VaTBhiXV/PDuAff+tGUxhkQror+X2KihQ0JJp1UDSyog4Ck9xV7iX8hev6Ch\\n1CAS8SGY7c9iontT68HQ+gKu3Z3ws4bJ24ePd3+Xln92qwmVObe39LJanl0HBGjL\\njVWw4ECq+R18GvkAudkKlmkaVbB95q2/iDMezbVidQIhgyRcUCftbLIyTSY8sZhG\\n9GodqugHOcU0I+pH5hv2ppA+a8ko3kCQBD9pRa6EuQInDx9vwPtOiMeUUL+u8ucB\\nBrYMgcP4mEq6eJpkNiBr6rPXR6xJJ3LkX75dXQIDAQABAoIBAA9WFvsqSAW3PmpB\\n+5QEkvJy5OAROOccbku7LdmIFfsUXlxWywBPmPDjJg9KUqzEtgp21TT1UsQwMmIS\\n2FD271jwX6Gbar9PIyLOf1G1453wRpcYjAumetYGXKMGPEbEJPxuLV/HMKbrk5lC\\nAxPosTyiHvwPdcHQ+9/AECcBsRG9hYSUou+ULewgS5CA7LJBQv1DRxWa0OtoChbu\\nmI2H+kShpvxjvMY5AaZHM/VmATDGCzVUNBwwiuj3IsbQmxxhLp1rQyvmUSyqcQiF\\n+PF5adXKJV/qFOkbKYMu+lfPZEderALevtCEep72+5L0/X984h6VgCF7jElqiZN3\\nQ+rwKkECgYEA5Z4aeDKhMutJMFPlS6Ucjfo4my5jP7p6vkuugnfdufF5Y+xwVk3I\\nMZSYZE6Gzc0Wpv+ZtmJipblNmvr0bTBDjb6WT4rsEDd+EG/vnBaul9cAci47iz+W\\nB5ClRg7NBr7KlPT9Qwm7HwY/53etv8ZDpyZrSem0mrTp55u+zC372VECgYEAyQAV\\nIeOtTjuUoQsLxrM2EktBRkSfqNHPU2ABVBwExNl7nCwljfQ17AouZ8x7FNcotBOl\\nUsp62+7BDYQi1pxkJPsfr1HxAAKgVd9ehgXLcVwhI3vJASVbRo9d0LG8plTjFWvD\\nXjwDjduwZnK8pIe1TepNAEEF85AyJiBCePueAE0CgYBscqzbwkXiT8AkhCtS++ut\\nntWnbVRQ4Bli0UndsxFU5hjIOf6gtGHuENmc3n3Kq6ecPjJyMquWzBs8LHTPMTFm\\nu/IwJVPzINJ4nvWTSh8x9cjvJKjYzrJkZku49/qbyfbSPZd0Vx86uu/pudulLNX9\\nFycrJKc5PmMPEb8enkVJ0QKBgQC+0vg9G1UuX7xEhCMi+oMMLSwEVSQq9z3Yzt2U\\nB6GzbTJAW10v/riuph/WZbg4WeiHxdr/1cF8SZg4h8k3bHRa85rqLGYb92JXBGBN\\n5vR1Y90GPf/fuaKFQ5jyh7stQovwi0WIknthUz+Ok8FqhnhnR1jhM9o9mRkzPw88\\nos0nRQKBgQC8i296TmSLqgBIZggv3zWacstTnUThKCvc4MAYqaSzRJUKpDrtYdxd\\nx0hkIoM4G+qPvKA8rpL0RMhmcf5xC/aZkqXmpG1V5vvwnf0GsvDn0zmbZ/2OwaI1\\nn+/XMxjr2N4h9wkWD2XgYWTcAnkRnYeSXxClyLeMzBYsOUJ7hxiwfA==\\n-----END RSA PRIVATE KEY-----\\n"

  docker run -it \
  -e port="8080" \
  -e slackToken="SLACKTOKEN" \
  -e circleCiTokens="CIRCLECITOKENS" \
  -e circleCiVcs="github" \
  -e circleCiProjects="4dmotion-ios@cci@4dmotion-android" \
  -e circleCiCompany="CIRCLECICOMPANY" \
  -e githubSecret="GITHUBSECRET" \
  -e githubAppId="22322" \
  -e githubPrivateKey="$GITHUBPRIVATEKEY" \
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

# run Cloudflare local http server to get a domain: use it on github repo's webhooks
# cloudflared tunnel --url http://localhost:8000

# sample call if you want to do locally:
# github.sh
