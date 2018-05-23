# cci
slack commands to circleci

## commands:
- help
- deploy alpha|beta|app_store [version] [groups] [emails]
- test branch

(on circleci there needs to be a *deploy* and *test* job, that can handle the parameters)

## environment variables:
These need to be set on your cloud provider or in docker container:
- *circleciToken*: token for the circleci API
- *slackToken*: verification token for the slack command
- *company*: company's name (that's in the circleci api url)
- *vcs*: the vcs used by circleci (github or bitbucket)
- *projects*: the projects that can be deployed (they have to be the same or the prefix for the slack channel, where the command is invomed)

