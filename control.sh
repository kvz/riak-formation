#!/usr/bin/env bash
# Transloadit Statuspage. Copyright (c) 2014, Transloadit Ltd.
#
# This file:
#
#  - Runs on a workstation
#  - Looks at cluster for cloud provider credentials, keys and their locations
#  - Takes a 1st argument, the step:
#    - prepare: Install prerequisites
#    - init   : Refreshes current infra state and saves to clusters/${RIFOR_CLUSTER}/terraform.tfstate
#    - plan   : Shows infra changes and saves in an executable plan
#    - launch : Launches virtual machines at a provider (if needed) using Terraform's ./default.tf
#    - seed   : Transmit the ./env and ./payload install scripts to remote homedir
#    - install: Runs the ./payload/install.sh remotely, installing system software
#    - upload : Upload the application
#    - setup  : Runs the ./payload/setup.sh remotely, installing app dependencies and starting it
#    - show   : Displays active platform
#  - Takes an optional 2nd argument: "done". If it's set, only 1 step will execute
#  - Will cycle through all subsequential steps. So if you choose 'upload', 'setup' will
#    automatically be executed
#  - Looks at RIFOR_DRYRUN cluster var. Set it to 1 to just show what will happen
#
# Run as:
#
#  ./control.sh upload
#
# Authors:
#
#  - Kevin van Zonneveld <kevin@transloadit.com>

set -o pipefail
set -o errexit
set -o nounset
# set -o xtrace

if [ -z "${RIFOR_CLUSTER:-}" ]; then
  echo "Deploy cluster '${RIFOR_CLUSTER}' not recognized. "
  echo "Please first e.g. source clusters/production/config.sh"
  exit 1
fi

# Set magic variables for current FILE & DIR
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

__rootdir="${__dir}"
__terraformdir="${__rootdir}/terraform"
__clusterdir="${__rootdir}/clusters/${RIFOR_CLUSTER}"
__exampledir="${__rootdir}/clusters/example"
__exampleinfrafile="${__exampledir}/default.tf"
__payloaddir="${__rootdir}/payload"
__terraformfile="${__terraformdir}/terraform"

__planfile="${__clusterdir}/terraform.plan"
__statefile="${__clusterdir}/terraform.tfstate"

terraform_version="0.3.1"



### Functions
####################################################################################

function syncUp() {
  [ -z "${host}" ] && host="$(${__terraformfile} output leader_address)"
  chmod 600 ${RIFOR_SSH_KEY_FILE}*
  rsync \
   --archive \
   --delete \
   --exclude=.git* \
   --exclude=node_modules \
   --exclude=terraform.* \
   --itemize-changes \
   --checksum \
   --no-times \
   --no-group \
   --no-motd \
   --no-owner \
   --rsh="ssh \
    -i \"${RIFOR_SSH_KEY_FILE}\" \
    -l ${RIFOR_SSH_USER} \
    -o UserKnownHostsFile=/dev/null \
    -o CheckHostIP=no \
    -o StrictHostKeyChecking=no" \
   ${@:2} \
  ${host}:${1}
}

function remote() {
  [ -z "${host}" ] && host="$(${__terraformfile} output leader_address)"
  chmod 600 ${RIFOR_SSH_KEY_FILE}*
  ssh ${host} \
    -i "${RIFOR_SSH_KEY_FILE}" \
    -l ${RIFOR_SSH_USER} \
    -o UserKnownHostsFile=/dev/null \
    -o CheckHostIP=no \
    -o StrictHostKeyChecking=no "${@:-}"
}

# Waits on first host, then does the rest in parallel
# This is so that the leader can be setup, and then all the followers can join
function inParallel () {
  cnt=0
  for host in $(${__terraformfile} output public_addresses); do
    let "cnt = cnt + 1"
    if [ "${cnt}" = 1 ]; then
      # wait on leader leader
      ${@}
    else
      ${@} &
    fi
  done

  fail=0
  for job in $(jobs -p); do
    # echo ${job}
    wait ${job} || let "fail = fail + 1"
  done
  if [ "${fail}" -ne 0 ]; then
    exit 1
  fi
}


### Vars
####################################################################################

dryRun="${RIFOR_DRYRUN:-0}"
step="${1:-prepare}"
afterone="${2:-}"
enabled=0
host=""


### Runtime
####################################################################################

pushd "${__clusterdir}" > /dev/null

if [ "${step}" = "remote" ]; then
  remote ${@:2}
  exit ${?}
fi

if [ "${step}" = "remote_follower" ]; then
  cnt=0
  for host in $(${__terraformfile} output public_addresses); do
    let "cnt = cnt + 1"
    if [ "${cnt}" = 2 ]; then
      remote ${@:2}
      exit $?
    fi
  done
fi

# We don't have a .tf file for this cluster, copy & use example.
if ! ls ${__clusterdir}/*.tf > /dev/null 2>&1; then
  echo "Borrowing ${__exampleinfrafile}"
  cp "${__exampleinfrafile}" ${__clusterdir}/default.tf
fi


processed=""
for action in "prepare" "init" "plan" "launch" "seed" "install" "upload" "setup" "show"; do
  [ "${action}" = "${step}" ] && enabled=1
  [ "${enabled}" -eq 0 ] && continue
  if [ -n "${processed}" ] && [ "${afterone}" = "done" ]; then
    break
  fi

  echo "--> ${RIFOR_HOSTNAME} - ${action}"

  if [ "${action}" = "prepare" ]; then
    os="linux"
    if [[ "${OSTYPE}" == "darwin"* ]]; then
      os="darwin"
    fi

    # Install brew/wget on OSX
    if [ "${os}" = "darwin" ]; then
      [ -z "$(which brew 2>/dev/null)" ] && ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
      [ -z "$(which wget 2>/dev/null)" ] && brew install wget
    fi

    # Install Terraform
    arch="amd64"
    filename="terraform_${terraform_version}_${os}_${arch}.zip"
    url="https://dl.bintray.com/mitchellh/terraform/${filename}"
    dir="${__terraformdir}"
    mkdir -p "${dir}"
    pushd "${dir}" > /dev/null
      if [ ! -f "${filename}" ] || ! ./terraform --version |grep "Terraform v${terraform_version}"; then
        rm -f "${filename}" || true
        wget "${url}"
        unzip -o "${filename}"
        rm -f "${filename}"
      fi
      ./terraform --version |grep "Terraform v${terraform_version}"
    popd > /dev/null

    # Install SSH Keys
    if [ ! -f "${RIFOR_SSH_KEY_FILE}" ]; then
      echo -e "\n\n" | ssh-keygen -t rsa -C "${RIFOR_SSH_EMAIL}" -f "${RIFOR_SSH_KEY_FILE}"
      echo "You'll need to add ${RIFOR_SSH_KEY_FILE}.pub to the provider"
    fi
    chmod 700 ${__rootdir}/clusters
    chmod 600 ${RIFOR_SSH_KEY_FILE}*

    processed="${processed} ${action}" && continue
  fi

  # Digital ocean:
  # ssh_key_fingerprint="$(ssh-keygen -lf ${RIFOR_SSH_KEY_FILE}.pub | awk '{print $2}')"

  terraformArgs=""
  terraformArgs="${terraformArgs} -var secret_key=\"${RIFOR_AWS_SECRET_KEY}\""
  terraformArgs="${terraformArgs} -var access_key=\"${RIFOR_AWS_ACCESS_KEY}\""
  terraformArgs="${terraformArgs} -var region=\"${RIFOR_AWS_REGION}\""
  terraformArgs="${terraformArgs} -var zone=\"${RIFOR_AWS_ZONE_ID}\""
  terraformArgs="${terraformArgs} -var key_path=\"${RIFOR_SSH_KEY_FILE}\""
  terraformArgs="${terraformArgs} -var key_name=\"${RIFOR_SSH_KEY_NAME}\""
  terraformArgs="${terraformArgs} -var cluster=\"${RIFOR_CLUSTER}\""

  if [ "${action}" = "init" ]; then
    # if [ ! -f ${__statefile} ]; then
    #   echo "Nothing to refresh yet."
    # else
    ${__terraformfile} refresh ${terraformArgs} || true
    # fi
  fi

  if [ "${action}" = "plan" ]; then
    rm -f ${__planfile}
    ${__terraformfile} plan -refresh=false ${terraformArgs} -out ${__planfile}
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "launch" ]; then
    if [ -f ${__planfile} ]; then
      echo "--> Press CTRL+C now if you are unsure! Executing plan in ${RIFOR_VERIFY_TIMEOUT}s..."
      [ "${dryRun}" -eq 1 ] && echo "--> Dry run break" && exit 1
      sleep ${RIFOR_VERIFY_TIMEOUT}
      ${__terraformfile} apply ${__planfile}
    else
      echo "Skipping, no changes. "
    fi
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "seed" ]; then
    # First enrich the payload with bash3boilerplate and cluster specific config
    rsync -a --progress --delete ${__rootdir}/node_modules/bash3boilerplate/ ${__payloaddir}/bash3boilerplate
    mkdir -p ${__payloaddir}/cluster
    cp ${__clusterdir}/config.sh ${__payloaddir}/cluster/
    cp ${__clusterdir}/ssl-key.* ${__payloaddir}/cluster/
    # Then syncUp upstream
    inParallel "syncUp" "~/payload/" "${__payloaddir}/*"
    rm -rf ${__payloaddir}/cluster
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "install" ]; then
    inParallel "remote" "bash -c \"source ~/payload/cluster/config.sh && sudo -E bash ~/payload/install.sh\""
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "upload" ]; then
    # seed, because folks will expect upload to also refresh the setup.sh and envs:
    # ${__file} seed done > /dev/null
    # actual app upload:
    # inParallel "syncUp" /srv/current "${__rootdir}/" --exclude=envs --exclude=scripts

    # We don't have an 'app' to upload
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "setup" ]; then
    inParallel "remote" "bash -c \"source ~/payload/cluster/config.sh && sudo -E bash ~/payload/setup.sh\""
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "show" ]; then
    remote "sudo riak-admin status | grep riak_kv_version"

    for host in $(${__terraformfile} output public_addresses); do
      echo "https://${RIFOR_USER}:${RIFOR_PASS}@${host}:8069/admin#/snapshot"
    done

    processed="${processed} ${action}" && continue
  fi
done
popd > /dev/null

if [ -f "${__clusterdir}/default.tf" ]; then
  echo "Cleaning up ${__clusterdir}/default.tf"
  rm -f "${__clusterdir}/default.tf"
fi

echo "--> ${RIFOR_HOSTNAME} - completed:${processed} : )"
