#!/bin/bash

## set ARG_HOME to a directory of your choosing if you do NOT
## want to to map the docker home directory to your local
## home directory

## use the command below on macOS or Linux to setup a 'launch'
## command. You can then use that command, e.g., launch ., to
## launch the container from any directory
## ln -s ~/start-jupyter.sh /usr/local/bin/launch

## to map the directory where the launch script is located to
## the docker home directory call the script_home function

function launch_usage() {
  echo "Usage: $0 [-t tag (version)] [-d directory]"
  echo "  -t, --tag         Docker image tag (version) to use"
  echo "  -d, --directory   Base directory to use"
  echo "  -h, --help        Print help and exit"
  echo ""
  echo "Example: $0 --tag 1.5.4 --directory ~/project_1"
  echo ""
  exit 1
}

## parse command-line arguments
while [[ "$#" > 0 ]]; do case $1 in
  -t|--tag) ARG_TAG="$2"; shift;shift;;
  -d|--directory) ARG_DIR="$2";shift;shift;;
  -h|--help) launch_usage;shift; shift;;
  *) echo "Unknown parameter passed: $1"; echo ""; launch_usage; shift; shift;;
esac; done

## some cleanup on exit
function finish {
  if [ "$ARG_HOME" != "" ]; then
    echo "Removing empty files and directories ..."
    find "$ARG_HOME" -empty -type d -delete
    find "$ARG_HOME" -empty -type f -delete
  fi
}
trap finish EXIT

## change to some other path to use as default

ARG_HOME=""
IMAGE_VERSION="latest"
ID="sbhathwar"
LABEL="jupyter-spark"
IMAGE=${ID}/${LABEL}


if [ "$ARG_TAG" != "" ]; then
  IMAGE_VERSION="$ARG_TAG"
  DOCKERHUB_VERSION=${IMAGE_VERSION}
else
  ## see https://stackoverflow.com/questions/34051747/get-environment-variable-from-docker-container
  DOCKERHUB_VERSION=$(docker inspect -f '{{range $index, $value := .Config.Env}}{{println $value}} {{end}}' ${IMAGE}:${IMAGE_VERSION} | grep DOCKERHUB_VERSION)
  DOCKERHUB_VERSION="${DOCKERHUB_VERSION#*=}"
fi
POSTGRES_VERSION=10

## what os is being used
ostype=`uname`
if [ "$ostype" == "Darwin" ]; then
  EXT="command"
else
  EXT="sh"
fi

## check if script is already running and using port 8787
CPORT=$(curl -s localhost:8787 2>/dev/null)
if [ "$CPORT" != "" ]; then
  echo "-----------------------------------------------------------------------"
  echo "A launch script may already be running. To close the new session and"
  echo "continue with the previous session press q + enter. To continue with"
  echo "the new session and stop the previous session, press enter"
  echo "-----------------------------------------------------------------------"
  read contd
  if [ "${contd}" == "q" ]; then
    exit 1
  fi
fi

## script to start JupyterLab
clear
has_docker=$(which docker)
if [ "${has_docker}" == "" ]; then
  echo "-----------------------------------------------------------------------"
  echo "Docker is not installed. Download and install Docker from"
  if [[ "$ostype" == "Linux" ]]; then
    echo "https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-on-ubuntu-18-04"
  elif [[ "$ostype" == "Darwin" ]]; then
    echo "https://download.docker.com/mac/stable/Docker.dmg"
  else
    echo "https://store.docker.com/editions/community/docker-ce-desktop-windows"
  fi
  echo "-----------------------------------------------------------------------"
  read
else

  ## check docker is running at all
  ## based on https://stackoverflow.com/questions/22009364/is-there-a-try-catch-command-in-bash
  {
    docker ps -q 2>/dev/null
  } || {
   if [[ "$ostype" == "Darwin" ]]; then
      ## from https://stackoverflow.com/a/48843074/1974918
      # On Mac OS this would be the terminal command to launch Docker
      open /Applications/Docker.app
      #Wait until Docker daemon is running and has completed initialisation
      while (! docker stats --no-stream 2>/dev/null); do
        echo "Please wait while Docker starts up ..."
        sleep 1
      done
    else
      echo "-----------------------------------------------------------------------"
      echo "Docker is not running. Please start docker on your computer"
      echo "When docker has finished starting up press [ENTER] to continue"
      echo "-----------------------------------------------------------------------"
      read
    fi
  }

  ## kill running containers
  running=$(docker ps -q)
  if [ "${running}" != "" ]; then
    echo "-----------------------------------------------------------------------"
    echo "Stopping running containers"
    echo "-----------------------------------------------------------------------"
    docker stop ${running}
  fi

  available=$(docker images -q ${IMAGE}:${IMAGE_VERSION})
  if [ "${available}" == "" ]; then
    echo "-----------------------------------------------------------------------"
    echo "Downloading the ${LABEL}:${IMAGE_VERSION} computing environment"
    echo "-----------------------------------------------------------------------"
    docker logout
    docker pull ${IMAGE}:${IMAGE_VERSION}
  fi

  BUILD_DATE=$(docker inspect -f '{{.Created}}' ${IMAGE}:${IMAGE_VERSION})

  echo "-----------------------------------------------------------------------"
  echo "Starting the ${LABEL} computing environment on ${ostype}"
  echo "Build date: ${BUILD_DATE//T*/}"
  echo "Base dir. /home/work: ${PWD}"
  echo "-----------------------------------------------------------------------"
  {
    docker run --rm -it --init -e 4040 -p 127.0.0.1:8888:8888 -p 127.0.0.1:8765:8765 \
      -p 127.0.0.1:4040:4040 -v "${PWD}":/home/work ${IMAGE}:${IMAGE_VERSION}
  } || {
    echo "-----------------------------------------------------------------------"
    echo "It seems there was a problem starting the docker container. Please"
    echo "report the issue and add a screenshot of any messages shown on screen."
    echo "Press [ENTER] to continue"
    echo "-----------------------------------------------------------------------"
    read
  }

fi
