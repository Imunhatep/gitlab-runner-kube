#!/bin/bash

# Test gitlab-runner name, token
if [ -z "$GITLAB_RUNNER_TOKEN" ]; then
  echo "info: GITLAB_RUNNER_TOKEN not provided"
  exit 126
fi

# If we are not provided with custom config
if [ -z "$CONFIG_FILE" ]; then
    cp /etc/gitlab-runner/config.toml.dist /etc/gitlab-runner/config.toml

    sed -i "s|{gitlab-runner-url}|$GITLAB_RUNNER_URL|" /etc/gitlab-runner/config.toml \
      && echo "Set gitlab-runner url"

    sed -i "s/{gitlab-runner-token}/$GITLAB_RUNNER_TOKEN/" /etc/gitlab-runner/config.toml \
      && echo "Set gitlab-runner token"
fi

unset GITLAB_RUNNER_NAME
unset GITLAB_RUNNER_TOKEN

chown gitlab-runner:gitlab-runner -R /home/gitlab-runner/.ssh
chmod 600 /home/gitlab-runner/.ssh/*

# gitlab-runner data directory
DATA_DIR="/etc/gitlab-runner"
CONFIG_FILE=${CONFIG_FILE:-$DATA_DIR/config.toml}

# custom certificate authority path
CA_CERTIFICATES_PATH=${CA_CERTIFICATES_PATH:-$DATA_DIR/certs/ca.crt}
LOCAL_CA_PATH="/usr/local/share/ca-certificates/ca.crt"

update_ca() {
  echo "Updating CA certificates..."
  cp "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}"
  update-ca-certificates --fresh >/dev/null
}

if [ -f "${CA_CERTIFICATES_PATH}" ]; then
  # update the ca if the custom ca is different than the current
  cmp --silent "${CA_CERTIFICATES_PATH}" "${LOCAL_CA_PATH}" || update_ca
fi

# setup kubectl
if [ ! -e "/var/run/secrets/kubernetes.io/serviceaccount/token" ]; then
  echo "Error: kube token not found"
  exit 127
fi

KUBE_TOKEN=$(cat "/var/run/secrets/kubernetes.io/serviceaccount/token")

# set kube auth
su - gitlab-runner -c 'kubectl config set-cluster kubernetes --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt'
su - gitlab-runner -c "kubectl config set-credentials gitlab-runner --token=${KUBE_TOKEN}"
su - gitlab-runner -c 'kubectl config set-context gitlab-runner@kubernetes --cluster=kubernetes --user=gitlab-runner'
su - gitlab-runner -c 'kubectl config use-context gitlab-runner@kubernetes'

# launch gitlab-runner passing all arguments
exec gitlab-runner "$@"
