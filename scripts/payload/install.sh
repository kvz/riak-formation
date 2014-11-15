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
#    config files, replacing placeholders with environment variables
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
__file="${__dir}/$(basename "${0}")"
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
  apt-get -fy dist-upgrade
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
echo "${RIFOR_APP_NAME} ${DEPLOY_ENV}" |figlet > /etc/motd


# echo "--> ${RIFOR_HOSTNAME} - Install MySQL"
# paint debconf-set-selections <<< "mysql-server mysql-server/root_password password ${RIFOR_MYSQL_ROOT_PASSWORD}"
# paint debconf-set-selections <<< "mysql-server mysql-server/root_password_again password ${RIFOR_MYSQL_ROOT_PASSWORD}"
# paint apt_install mysql-server 5.5.35


# echo "--> ${RIFOR_HOSTNAME} - Configure MySQL to allow connections from OSX. Production can stay local"
# ./bash3boilerplate/src/templater.sh ./templates/mysql.sh /etc/mysql/my.cnf
# service mysql restart

# echo "--> ${RIFOR_HOSTNAME} - Setup MySQL database schema"
# # Default (dev or production)
# echo "CREATE DATABASE IF NOT EXISTS \`${RIFOR_MYSQL_DBNAME}\` DEFAULT CHARACTER SET utf8;" | paint mysql --defaults-file=/etc/mysql/debian.cnf
# # Test (can be done on dev or production)
# echo "CREATE DATABASE IF NOT EXISTS \`${RIFOR_MYSQL_TESTDBNAME}\` DEFAULT CHARACTER SET utf8;" | paint mysql --defaults-file=/etc/mysql/debian.cnf


# echo "--> ${RIFOR_HOSTNAME} - Setup MySQL user for app"
# # Default (dev or production)
# paint mysql -uroot -p${RIFOR_MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON \`${RIFOR_MYSQL_DBNAME}\`.* to ${RIFOR_MYSQL_USER}@'%' IDENTIFIED BY \"${RIFOR_MYSQL_PASS}\";" ${RIFOR_MYSQL_DBNAME}
# paint mysql -uroot -p${RIFOR_MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON \`${RIFOR_MYSQL_DBNAME}\`.* to ${RIFOR_MYSQL_USER}@localhost IDENTIFIED BY \"${RIFOR_MYSQL_PASS}\";" ${RIFOR_MYSQL_DBNAME}
# # Test (can be done on dev or production)
# paint mysql -uroot -p${RIFOR_MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON \`${RIFOR_MYSQL_TESTDBNAME}\`.* to ${RIFOR_MYSQL_USER}@'%' IDENTIFIED BY \"${RIFOR_MYSQL_PASS}\";" ${RIFOR_MYSQL_TESTDBNAME}
# paint mysql -uroot -p${RIFOR_MYSQL_ROOT_PASSWORD} -e "GRANT ALL ON \`${RIFOR_MYSQL_TESTDBNAME}\`.* to ${RIFOR_MYSQL_USER}@localhost IDENTIFIED BY \"${RIFOR_MYSQL_PASS}\";" ${RIFOR_MYSQL_TESTDBNAME}


echo "--> ${RIFOR_HOSTNAME} - Install Redis"
paint apt_install redis-server


echo "--> ${RIFOR_HOSTNAME} - Install Nginx"
paint apt_install nginx 1.1.19

./bash3boilerplate/src/templater.sh ./templates/nginx.sh /etc/nginx/nginx.conf
./bash3boilerplate/src/templater.sh ./templates/nginx-vhost.sh /etc/nginx/sites-available/${RIFOR_APP_NAME}
ln -nfs /etc/nginx/{sites-available/${RIFOR_APP_NAME},sites-enabled/${RIFOR_APP_NAME}}
rm -f /etc/nginx/sites-enabled/default
service nginx restart


echo "--> ${RIFOR_HOSTNAME} - Install Upstart script for ${RIFOR_APP_NAME}"
./bash3boilerplate/src/templater.sh ./templates/upstart-${RIFOR_APP_NAME}.sh /etc/init/${RIFOR_APP_NAME}.conf


echo "--> ${RIFOR_HOSTNAME} - Install Convenience scripts for root user"
if ! grep -q "envs/${DEPLOY_ENV}.sh" /root/.bashrc; then
  # avoid the risk of an exit !=0 will prevent logins
  echo "cd \"${RIFOR_APP_DIR}\" && source ~/envs/${DEPLOY_ENV}.sh && source ~/payload/login.sh || true" >> /root/.bashrc
fi
if [ -d /home/vagrant ]; then
  echo "--> ${RIFOR_HOSTNAME} - Install Convenience scripts for vagrant user"
  if ! grep -q "envs/${DEPLOY_ENV}.sh" /home/vagrant/.bashrc; then
    # avoid the risk of an exit !=0 will prevent logins
    echo "cd \"${RIFOR_APP_DIR}\" && source ~/envs/${DEPLOY_ENV}.sh && source ~/payload/login.sh || true" >> /home/vagrant/.bashrc
  fi
fi

paint apt_install htop
paint apt_install iotop
paint apt_install apg
paint apt_install mtr
paint apt_install logtail
paint apt_install git-core
paint apt_install python-pip


echo "--> ${RIFOR_HOSTNAME} - Install node.js"
if [ ! -f /etc/apt/sources.list.d/chris-lea-node_js-precise.list ]; then
  paint apt_install python
  paint apt_install python-software-properties
  add-apt-repository --yes ppa:chris-lea/node.js
  apt-get -qq update
fi
paint apt_install nodejs 0.10.26


echo "--> ${RIFOR_HOSTNAME} - Install munin"
apt_install munin
apt_install munin-node
apt_install munin-plugins-extra
apt_install apache2-utils
htpasswd -b -c /etc/nginx/htpasswd ${RIFOR_MUNIN_WEB_USER} ${RIFOR_MUNIN_WEB_PASS}
ln -nfsv /usr/share/munin/plugins/nginx_request     /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/nginx_status      /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_slowqueries /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_threads     /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_queries     /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_bytes       /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_innodb      /etc/munin/plugins/

./bash3boilerplate/src/templater.sh ./templates/munin.sh /etc/munin/munin.conf
munin-node-configure --suggest --shell 2>/dev/null | bash || true
service munin-node restart
chgrp -R ${RIFOR_SERVICE_GROUP} /var/cache/munin/www


echo "--> ${RIFOR_HOSTNAME} - Create app root"
mkdir -p "${RIFOR_APP_DIR}"
