# cci
- slack commands to circleci
- githubwebhooks to youtrack

## commands:
- help
- deploy alpha|beta|app_store [version] [groups] [emails]
- test branch

(on circleci there needs to be a *deploy* and *test* job, that can handle the parameters)

## environment variables:
These need to be set on your cloud provider or in docker container:
- *slackToken*: verification token for the slack command
- *circleCiToken*: token for the circleci API
- *circleCiCompany*: company's name (that's in the circleci api url)
- *circleCiVcs*: the vcs used by circleci (github or bitbucket)
- *circleCiProjects*: the projects that can be deployed (they have to be the same or the prefix for the slack channel, where the command is invomed)

- *githubSecret*: github secret for webhook verification
- *youtrackURL*: url of youtrack instance
- *youtrackToken*: token for youtrack API authentication

