#!/usr/bin/env bash
# Transloadit Statuspage. Copyright (c) 2014, Transloadit Ltd.
#
# This file:
#
#  - Runs on a workstation
#  - Looks at environment for cloud provider credentials, keys and their locations
#  - Takes a 1st argument, the step:
#    - prepare: Install prerequisites
#    - init   : Refreshes current infra state and saves to ./terraform.tfstate
#    - launch : Launches virtual machines at a provider (if needed) using Terraform's ./infra.tf
#    - seed   : Transmit the ./env and ./payload install scripts to remote homedir
#    - install: Runs the ./payload/install.sh remotely, installing system software
#    - upload : Upload the application
#    - setup  : Runs the ./payload/setup.sh remotely, installing app dependencies and starting it
#  - Takes an optional 2nd argument: "done". If it's set, only 1 step will execute
#  - Will cycle through all subsequential steps. So if you choose 'upload', 'setup' will
#    automatically be executed
#  - Looks at RIFOR_DRYRUN environment var. Set it to 1 to just show what will happen
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

# Set magic variables for current FILE & DIR
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

terraform_version="0.3.1"


### Vars
####################################################################################

dryRun="${RIFOR_DRYRUN:-0}"
step="${1:-prepare}"
afterone="${2:-}"
enabled=0
remote_ip=""


### Runtime
####################################################################################


if [ "${step}" = "remote" ]; then
  remote ${@:2}
  exit ${?}
fi

pushd "${__dir}" > /dev/null
processed=""
for action in "prepare" "init" "plan" "launch" "seed" "install" "upload" "setup"; do
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
    terraform_version="0.3.1"
    arch="amd64"
    filename="terraform_${terraform_version}_${os}_${arch}.zip"
    url="https://dl.bintray.com/mitchellh/terraform/${filename}"
    dir="${__dir}/terraform"
    mkdir -p "${dir}"
    pushd "${dir}" > /dev/null
      if [ ! -f "${filename}" ] || ! ./terraform --version |grep "Terraform v${terraform_version}"; then
        rm -f "${filename}" || true
        wget "${url}"
        unzip -o "${filename}"
      fi
      ./terraform --version |grep "Terraform v${terraform_version}"
    popd > /dev/null


    # Install SSH Keys
    if [ ! -f "${RIFOR_SSH_KEY_FILE}" ]; then
      echo -e "\n\n" | ssh-keygen -t rsa -C "${RIFOR_SSH_EMAIL}" -f "${RIFOR_SSH_KEY_FILE}"
      notice "You'll need to add ${RIFOR_SSH_KEY_FILE}.pub to the provider"
    fi
    chmod 700 ${__root}/envs
    chmod 600 ${RIFOR_SSH_KEY_FILE}*

    processed="${processed} ${action}" && continue
  fi

  # ssh_key_fingerprint="$(ssh-keygen -lf ${RIFOR_SSH_KEY_FILE}.pub | awk '{print $2}')"

  terraformArgs=""
  # if [ "${debug}" = "1" ]; then
  #   terraformArgs="${terraformArgs} -debug"
  # fi
  terraformArgs="${terraformArgs} -var secret_key=${RIFOR_AWS_SECRET_KEY}"
  terraformArgs="${terraformArgs} -var access_key=${RIFOR_AWS_ACCESS_KEY}"
  terraformArgs="${terraformArgs} -var region=${RIFOR_AWS_REGION}"
  terraformArgs="${terraformArgs} -var zone=${RIFOR_AWS_ZONE_ID}"
  # terraformArgs="${terraformArgs} -var RIFOR_DOMAIN=${RIFOR_DOMAIN}"
  terraformArgs="${terraformArgs} -var key_path=${RIFOR_SSH_KEY_FILE}"
  terraformArgs="${terraformArgs} -var key_name=${RIFOR_SSH_KEY_NAME}"


  if [ "${action}" = "init" ]; then
    if [ ! -f terraform.tfstate ]; then
      echo "Nothing to refresh yet."
    else
      ./terraform/terraform refresh ${terraformArgs}
    fi
  fi

  if [ "${action}" = "plan" ]; then
    ./terraform/terraform plan ${terraformArgs} -out ./plan
    echo "--> Press CTRL+C now if you are unsure! Executing plan in 10s"
    sleep 10
    processed="${processed} ${action}" && continue
  fi

  [ "${dryRun}" -eq 1 ] && echo "--> Dry run break" && exit 1

  if [ "${action}" = "launch" ]; then
    ./terraform/terraform apply ${terraformArgs} ./plan
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "seed" ]; then
    rsync -a --progress "${__root}/node_modules/bash3boilerplate/" "${__dir}/payload/bash3boilerplate"
    sync "~/" "${__dir}/payload" "${__root}/envs"
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "install" ]; then
    remote "source ~/envs/${DEPLOY_ENV}.sh && cd ~/payload && ./install.sh"
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "upload" ]; then
    # seed, because folks will expect upload to also refresh the setup.sh and envs:
    ${__file} seed done > /dev/null
    # actual app upload:
    sync /srv/current "${__root}/" --exclude=envs --exclude=scripts
    processed="${processed} ${action}" && continue
  fi

  if [ "${action}" = "setup" ]; then
    remote "source ~/envs/${DEPLOY_ENV}.sh && cd ~/payload && ./setup.sh"
    processed="${processed} ${action}" && continue
  fi
done
popd > /dev/null

echo "--> ${RIFOR_HOSTNAME} - completed:${processed} : )"
