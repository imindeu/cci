#!/bin/sh

# usage:
#  - with default arguments:
#      slack.sh
#  - with custom arguments:
#      slack.sh [command] [arguments...]
#      command and arguments: same as in slack channel after "/cci"

if [ "$#" -eq 0 ]; then
# if there are no args, use default coomand
    SALCK_COMMAND='deploy'
    SALCK_TEXT='deploy fourd alpha emails:gab.horv@gmail.com unofficial_release:true custom_change_log:"Test changelog with spaces" feature/4DM-5808-Update-deploy-from-custom-branch'
else
# if there are args, use them
    SALCK_COMMAND=$1
    SALCK_TEXT=$@
fi

# send request
#  - method: POST
#  - port: 8080 - localhost port of docker image
#  - slackCommand: url path of slack commands
curl -d "token=SLACKTOKEN&team_id=team_id&team_domain=team_domain&channel_id=channel_id&channel_name=4dmotion-ios&user_id=user_id&user_name=user_name&command=$SALCK_COMMAND&text=$SALCK_TEXT&response_url=http://testresponseurl.com:1234&trigger_id=trigger_id" \
    -X POST \
    http://localhost:8080/slackCommand
