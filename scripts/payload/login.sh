#!/usr/bin/env bash
# Transloadit Statuspage. Copyright (c) 2014, Transloadit Ltd.
#
# This file:
#
#  - sources environment and provides convenience aliases such as `wtf`
#
# It's typically called from .bashrc, and written there by install.sh
#
# Authors:
#
#  - Kevin van Zonneveld <kevin@transloadit.com>

echo "Sourced environment for this session: '${DEPLOY_ENV}'"

# set -o xtrace
echo "Creating wtf alias"
alias wtf='sudo tail -f /var/log/*{log,err} /var/log/{dmesg,messages,*{,/*}{log,err}}'
