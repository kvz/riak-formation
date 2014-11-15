#!/usr/bin/env bash
# Transloadit Statuspage. Copyright (c) 2014, Transloadit Ltd.
#
# This file:
#
#  - assumes it's run as root
#  - assumes it's run inside the payload directory
#  - installs app dependencies
#  - (re)starts the app
#
# It's typically called by a deploy to run onto servers or vboxes
#
# Authors:
#
#  - Kevin van Zonneveld <kevin@transloadit.com>

set -o pipefail
set -o errexit
set -o nounset
# set -o xtrace

if [ -z "${DEPLOY_ENV}" ]; then
  echo "Environment ${DEPLOY_ENV} not recognized. "
  echo "Please first source envs/development.sh or source envs/production.sh"
  exit 1
fi

if [[ "${OSTYPE}" == "darwin"* ]]; then
  echo "Please only run this on a (virtual) server"
  exit 1
fi

# Set magic variables for current FILE & DIR
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"


function paint () (
  set -o pipefail

  green=$'s,.*,\x1B[32m&\x1B[m,'
  red=$'s,.*,\x1B[31m&\x1B[m,'
  gray=$'s,.*,\x1B[37m&\x1B[m,'
  darkgray=$'s,.*,\x1B[1m&\x1B[m,'
  purge="/.*/d"

  stdout="${green}"
  stderr="${red}"

  ("${@}" 2>&1>&3 |sed ${stderr} >&2) 3>&1 \
                  |sed ${stdout}
)


echo "--> ${RIFOR_HOSTNAME} - Install node modules"
exit 1
if ! which coffee; then
  paint npm install -g coffee-script
fi
cd "${RIFOR_APP_DIR}"
paint npm install


echo "--> ${RIFOR_HOSTNAME} - Setup file permissions"
chown -R ${RIFOR_SERVICE_USER}.${RIFOR_SERVICE_GROUP} "${RIFOR_APP_DIR}"


echo "--> ${RIFOR_HOSTNAME} - Reloading redis-server"
sudo service redis-server restart || (sudo service redis-server stop; sudo service redis-server start)


echo "--> ${RIFOR_HOSTNAME} - Reloading nginx"
sudo service nginx reload || (sudo service nginx stop; sudo service nginx start)


echo "--> ${RIFOR_HOSTNAME} - Reloading ${RIFOR_APP_NAME}"
sudo service ${RIFOR_APP_NAME} stop || true
sudo service ${RIFOR_APP_NAME} start
