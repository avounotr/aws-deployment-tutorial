#!/usr/bin/env bash

# //////////////////////////////////////////////////////////////////////////////
# This script's purpose is to let you automatically deploy the Applications on
# aws server
#
# It is meant to be pretty general purpose, but you will likely want to make a
# few edits to customize it for your application or framework's needs.
#
# It is expected that you will at least configure your application by configuring
# the variables below this comment block.
#
# You may also want to adjust a few of the functions to customize them for your
# application. I needed to make a judgment call to balance out making the script
# somewhat general purpose and easy to understand without being a bash wizard.
# //////////////////////////////////////////////////////////////////////////////

# Exit the script as soon as something fails.
set -e

# What is the application's path?
APPLICATION_PATH="$HOME/Development/AwsProject"

# What is your Docker registry's URL?
REGISTRY="269286422109.dkr.ecr.us-east-1.amazonaws.com"

# How is the application defined in your docker-compose.yml file?
APPLICATION_NAME1="application"
APPLICATION_NAME2="blog"
APPLICATION_NAME3="nginx"

# What is the Docker image's name?
IMAGE1="test/application"
IMAGE2="docker.id/wordpress"
IMAGE3="test/nginx"


# What is the repository's name?
REPO1="test/application"
REPO2="test/blog"
REPO3="test/nginx"

# Which build are you pushing?
BUILD="latest"

# Which cluster are you acting on?
CLUSTER="test-cluster"

# //////////////////////////////////////////////////////////////////////////////
# Optional steps that you may want to implement on your own!
# ------------------------------------------------------------------------------
# Run the application's test suite to ensure you always push working builds.
# Push your code to a remote source control management service such as GitHub.
# //////////////////////////////////////////////////////////////////////////////

function push_to_registry () {
  # Move into the application's path and build the Docker image.
  cd "${APPLICATION_PATH}/${APPLICATION_NAME1}" && sudo docker build -t test/application . && cd -
  cd "${APPLICATION_PATH}/${APPLICATION_NAME2}" && docker-compose build && cd -
  cd "${APPLICATION_PATH}/${APPLICATION_NAME3}" && docker-compose build && cd -

  docker tag "${IMAGE1}:${BUILD}" "${REGISTRY}/${REPO1}:${BUILD}"
  docker tag "${IMAGE2}:${BUILD}" "${REGISTRY}/${REPO2}:${BUILD}"
  docker tag "${IMAGE3}:${BUILD}" "${REGISTRY}/${REPO3}:${BUILD}"

  # Automatically refresh the authentication token with ECR.
  eval "$(aws ecr get-login)"

  docker push "${REGISTRY}/${REPO1}"
  docker push "${REGISTRY}/${REPO2}"
  docker push "${REGISTRY}/${REPO3}"
}

function update_web_service () {
  aws ecs register-task-definition \
    --cli-input-json file://web-task-definition.json
  aws ecs update-service --cluster "${CLUSTER}" --service web \
    --task-definition web --desired-count 2
}

function all () {
  # Call the other functions directly, but skip migrating simply because you
  # should get used to running migrations as a separate task.
  push_to_registry
  update_web_service
}

function help_menu () {
cat << EOF
Usage: ${0} (-h | -p | -w | -r | -d | -a)

OPTIONS:
   -h|--help             Show this message
   -p|--push-to-registry Push the web application to your private registry
   -w|--update-web       Update the web application

EXAMPLES:
   Push the web application to your private registry:
        $ ./deploy.sh -p

   Update the web application:
        $ ./deploy.sh -w

EOF
}

# Deal with command line flags.
while [[ $# > 0 ]]
do
case "${1}" in
  -p|--push-to-registry)
  push_to_registry
  shift
  ;;
  -w|--update-web)
  update_web_service
  shift
  ;;
  -r|--update-worker)
  update_worker_service
  shift
  ;;
  *)
  echo "${1} is not a valid flag, try running: ${0} --help"
  ;;
esac
shift
done
