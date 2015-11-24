#!/usr/bin/env bash

# Base path for sharing between DOCKER Host and containers
export SHARED_HOST_FOLDER="${HOME}/Sharing/MoodleDocker"

# Shared www and data paths
export SHARED_WWW="${SHARED_HOST_FOLDER}/www"
export SHARED_LOG="${SHARED_HOST_FOLDER}/log"
export SHARED_DATA="${SHARED_HOST_FOLDER}/data"

# MySQL Configurations
export MYSQL_ALLOW_EMPTY_PASSWORD="yes"
export MYSQL_ROOT_PASSWORD="moodle"
export MYSQL_DATABASE="moodle"
export MYSQL_USER="moodle"
export MYSQL_PASSWORD="moodle"
export MYSQL_DATADIR="${SHARED_DATA}/mysql"

# Moodle Configuration
export APACHE_WWW_ROOT="/var/www/html"
export MOODLE_WWW_ROOT="${APACHE_WWW_ROOT}/moodle"
export MOODLE_DATA_DIR="/data/moodle"
export MOODLE_LOG_DIR="/var/log/apache2"
export SHARED_MOODLE_WWW_ROOT="${SHARED_WWW}/moodle"
export SHARED_MOODLE_LOG_DIR="${SHARED_LOG}/moodle"
export SHARED_MOODLE_DATA_DIR="${SHARED_DATA}/moodle"

# SSH service of the Moodle container # TODO: needed?
CONTAINER_SSH_PORT=4376

  #--> SSH KEY <--
SSH_KEY="${HOME}/.ssh/id_dsa.pub"
if [[ ! -f ${SSH_KEY} ]]; then
	SSH_KEY="${HOME}/.ssh/id_rsa.pub"
fi
export SSH_KEY_PATH=$SSH_KEY


