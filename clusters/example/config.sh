__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CLUSTER="production"
export RIFOR_AWS_ACCESS_KEY="xxx"
export RIFOR_AWS_SECRET_KEY="xxx"
export RIFOR_AWS_REGION="us-east-1"
export RIFOR_AWS_ZONE_ID="xxx"
export RIFOR_SSH_EMAIL="hello@example.com"
export RIFOR_DRYRUN="1"
export RIFOR_APP_DIR="/srv/current"
export RIFOR_APP_NAME="riak-formation"
export RIFOR_HOSTNAME="$(uname -n)"
export RIFOR_SSH_KEY_FILE="${__dir}/ssh-key.pem"
export RIFOR_SSH_KEY_NAME="xxx"
export RIFOR_SSH_USER="ubuntu"
export RIFOR_VERIFY_TIMEOUT="10"
export RIFOR_MUNIN_WEB_USER="munin"
export RIFOR_MUNIN_WEB_PASS="munin"

export RIFOR_SERVER_COUNT="$(cat ${__root}/riak-server-count 2>/dev/null)" || true
export RIFOR_LEADER_ADDR="$(cat ${__root}/riak-leader-addr 2>/dev/null)" || true
export RIFOR_LEADER_PRIVATE_IP="$(cat ${__root}/riak-leader-private-ip 2>/dev/null)" || true
export RIFOR_SELF_ADDR="$(cat ${__root}/riak-self-addr 2>/dev/null)" || true
export RIFOR_SELF_PRIVATE_IP="$(cat ${__root}/riak-self-private-ip 2>/dev/null)" || true
export RIFOR_NODENAME="riak@${RIFOR_SELF_PRIVATE_IP}"
