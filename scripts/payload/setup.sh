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


echo "--> ${RIFOR_HOSTNAME} - Reloading Nginx"
bash ${__dir}/bash3boilerplate/src/templater.sh ${__dir}/templates/nginx.sh /etc/nginx/nginx.conf
bash ${__dir}/bash3boilerplate/src/templater.sh ${__dir}/templates/nginx-vhost.sh /etc/nginx/sites-available/${RIFOR_APP_NAME}
ln -nfs /etc/nginx/{sites-available/${RIFOR_APP_NAME},sites-enabled/${RIFOR_APP_NAME}}
rm -f /etc/nginx/sites-enabled/default
service nginx restart


echo "--> ${RIFOR_HOSTNAME} - Reloading Munin"
htpasswd -b -c /etc/nginx/htpasswd ${RIFOR_MUNIN_WEB_USER} ${RIFOR_MUNIN_WEB_PASS}
ln -nfsv /usr/share/munin/plugins/nginx_request     /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/nginx_status      /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_slowqueries /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_threads     /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_queries     /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_bytes       /etc/munin/plugins/
ln -nfsv /usr/share/munin/plugins/mysql_innodb      /etc/munin/plugins/

${__dir}/bash3boilerplate/src/templater.sh ${__dir}/templates/munin.sh /etc/munin/munin.conf
munin-node-configure --suggest --shell 2>/dev/null | bash || true
chgrp -R www-data /var/cache/munin/www
service munin-node restart


echo "--> ${RIFOR_HOSTNAME} - Install Self signed certificate"
rsync -a --progress ${__dir}/ssl/* /etc/riak/
pushd /etc/riak
  if [ ! -f server.key ]; then
    openssl req -nodes -x509 -newkey rsa:4096 -keyout server.key -out server.csr -days 356 -subj "/C=US/ST=Oregon/L=Portland/O=IT/CN=www.example.com"
  fi
popd


echo "--> ${RIFOR_HOSTNAME} - Reloading Riak"
bash ${__dir}/bash3boilerplate/src/templater.sh ${__dir}/templates/riak.sh /etc/riak/riak.conf
# mount -o remount,noatime /var/lib/riak/bitcask # <-- @todo: mount separate device for this
ulimit -n 65536
echo 'ulimit -n 65536' > /etc/default/riak
service riak reload || (service riak stop; service riak start)

# riak-admin diag

if [ "${RIFOR_LEADER_PRIVATE_IP}" == "${RIFOR_SELF_PRIVATE_IP}" ]; then
  echo "I am the first node, so no joining"
else
  if riak-admin member-status |grep "${RIFOR_SELF_PRIVATE_IP}" |egrep '^(valid|joining)'; then
    if riak-admin member-status |grep "${RIFOR_LEADER_PRIVATE_IP}" |egrep '^(valid|joining)'; then
      echo "Already joined the correct cluster"
    else
      echo "In the wrong cluster, could not find leader. Leaving"
      riak-admin cluster leave riak@${RIFOR_LEADER_PRIVATE_IP}
      riak-admin cluster plan
      riak-admin cluster commit
    fi
  fi

  if ! riak-admin member-status |grep "${RIFOR_SELF_PRIVATE_IP}" |egrep '^(valid|joining)'; then
    echo "Joing cluster"
    riak-admin cluster join riak@${RIFOR_LEADER_PRIVATE_IP}
    riak-admin cluster plan
    riak-admin cluster commit
  fi
fi

riak-admin member-status

# riak-admin ring_status
