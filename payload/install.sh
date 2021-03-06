#!/usr/bin/env bash
# Transloadit Statuspage. Copyright (c) 2014, Transloadit Ltd.
#
# This file:
#
#  - assumes it's run as root
#  - assumes it's run inside the payload directory
#  - installs all prerequisites for running our app. such as:
#     - system utilites & upgrades
#     - MySQL
#     - Nginx as (SSL) proxy
#     - node.js
#     - munin monitoring
#  - uses ./bash3boilerplate/src/templater.sh and ./templates/* to write (e.g. nginx)
#    config files, replacing placeholders with cluster variables
#  - installs login.sh that is run upon logging in and contains
#    sysadmin convenience shortcuts such as sourcing env and the alias `wtf`
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

if [ -z "${RIFOR_CLUSTER}" ]; then
  echo "Deploy cluster '${RIFOR_CLUSTER}' not recognized. "
  echo "Please first e.g. source clusters/production/config.sh"
  exit 1
fi

if [[ "${OSTYPE}" == "darwin"* ]]; then
  echo "Please only run this on a (virtual) server"
  exit 1
fi

# Set magic variables for current FILE & DIR
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"


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

function apt_install () {
  local wanted_package="${1}"
  local wanted_version="${2:-}"
  installed_status=$(dpkg-query -W --showformat='${Status}\n' ${wanted_package}|grep "install ok installed") || true
  installed_version=$(dpkg-query -W --showformat='${Version}\n' ${wanted_package}|awk -F\- '{print $1}') || true
  echo "Checking for ${wanted_package} ${wanted_version}: ${installed_status}"
  if [ "${installed_status}" = "" ]; then
    echo "Failed ${wanted_package}. Setting up ${wanted_package}."
    apt-get --force-yes --yes install ${1}
  fi

  if [ ! -z "${wanted_version}" ] && [ "${installed_version}" != "${wanted_version}" ]; then
    echo "Version mismatch ${wanted_package}. Setting up ${wanted_package}."
    apt-get --force-yes --yes install ${1}
  fi
}

echo "--> ${RIFOR_HOSTNAME} - Setup apt"
export DEBIAN_FRONTEND=noninteractive
echo "deb http://us.archive.ubuntu.com/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
" > /etc/apt/sources.list
# Apt-get update, but only if it's old
find ~/.apt-updated -mmin -300 || (apt-get -qq update && touch ~/.apt-updated)


if [ 1 -eq 1 ]; then
  echo "--> ${RIFOR_HOSTNAME} - Upgrade all packages"
  yes| apt-get -qqfy --force-yes dist-upgrade || true
else
  echo "--> ${RIFOR_HOSTNAME} - Upgrade packages with vulnerabilities"
  unattended-upgrade
fi


echo "--> ${RIFOR_HOSTNAME} - Set timezone to UTC if needed .."
if [ "$(cat /etc/timezone)" != "Etc/UTC" ]; then
  echo "Etc/UTC" | tee /etc/timezone
  dpkg-reconfigure --frontend noninteractive tzdata
fi


echo "--> ${RIFOR_HOSTNAME} - Install system requirements"
paint apt_install make
paint apt_install figlet
paint apt_install update-notifier-common


echo "--> ${RIFOR_HOSTNAME} - Setup MOTD"
echo "${RIFOR_APP_NAME} ${RIFOR_CLUSTER}" |figlet > /etc/motd


echo "--> ${RIFOR_HOSTNAME} - Install Convenience scripts for root user"
envUser=""
if [ -d /home/vagrant ]; then
  echo "--> ${RIFOR_HOSTNAME} - Install Convenience scripts for vagrant user"
  envUser="vagrant"
  if ! grep -q "config.sh" /home/vagrant/.bashrc; then
    # avoid the risk of an exit !=0 will prevent logins
    echo "cd \"${RIFOR_APP_DIR}\" && source ~/cluster/config.sh && source ~/payload/login.sh || true" >> /home/vagrant/.bashrc
    chown vagrant /home/vagrant/.bashrc
  fi
fi
if [ -d /home/ubuntu ]; then
  echo "--> ${RIFOR_HOSTNAME} - Install Convenience scripts for ubuntu user"
  envUser="ubuntu"
  if ! grep -q "config.sh" /home/ubuntu/.bashrc; then
    # avoid the risk of an exit !=0 will prevent logins
    echo "cd \"${RIFOR_APP_DIR}\" && source ~/cluster/config.sh && source ~/payload/login.sh || true" >> /home/ubuntu/.bashrc
    chown ubuntu /home/ubuntu/.bashrc
  fi
fi
if ! grep -q "config.sh" /root/.bashrc; then
  # avoid the risk of an exit !=0 will prevent logins
  echo "cd \"${RIFOR_APP_DIR}\" && source ~${envUser}/cluster/config.sh && source ~${envUser}/payload/login.sh || true" >> /root/.bashrc
  chown root /root/.bashrc
fi

paint apt_install htop
paint apt_install iotop
paint apt_install apg
paint apt_install mtr
paint apt_install logtail
paint apt_install realpath
# paint apt_install git-core


echo "--> ${RIFOR_HOSTNAME} - Install Riak"

hostname=`hostname -f`
filename=/etc/apt/sources.list.d/basho.list
os=ubuntu
dist=precise
package_cloud_riak_dir=https://packagecloud.io/install/repositories/basho/riak

if [ ! -f ${filename} ]; then
  curl "${package_cloud_riak_dir}/config_file.list?os=${os}&dist=${dist}&name=${hostname}" |tee ${filename}
  apt-get -qq update
fi
# http://docs.basho.com/riak/latest/ops/building/installing/debian-ubuntu/#Advanced-apt-Installation
paint apt_install libpam0g-dev
paint apt_install libssl0.9.8
paint apt_install riak


echo "--> ${RIFOR_HOSTNAME} - Install Nginx"
paint apt_install nginx 1.1.19


echo "--> ${RIFOR_HOSTNAME} - Install Munin"
apt_install munin
apt_install munin-node
apt_install munin-plugins-extra
apt_install apache2-utils


echo "--> ${RIFOR_HOSTNAME} - Create app root"
mkdir -p "${RIFOR_APP_DIR}"
