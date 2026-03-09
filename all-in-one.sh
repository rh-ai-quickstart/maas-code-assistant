#!/bin/bash

set -e
cd "$(dirname "$(realpath "$0")")"

if [ -r .env ]; then
  . .env
fi
if [ -z "$ADMIN_PASSWORD" ]; then
  read -rsp 'Enter a password to set for the admin user (will be created): ' ADMIN_PASSWORD
  echo "ADMIN_PASSWORD=\"$ADMIN_PASSWORD\"" >> .env
fi
echo
if [ -z "$USER_PASSWORD" ]; then
  read -rsp 'Enter a password to set for the generated users (user1-user5 by default): ' USER_PASSWORD
  echo "USER_PASSWORD=\"$USER_PASSWORD\"" >> .env
fi
echo

function noisy {
  local censored=()
  while [ "$1" = "-c" ]; do
    shift;
    censored+=("$1")
    shift;
  done
  local clean="${*}"
  for var in "${censored[@]}"; do
    clean="${clean/$var/<CENSORED>}"
  done
  echo "+ ${clean}"
  "${@}"
}

if ! [ -e charts/maas-code-assistant/all-dependencies.yaml ]; then
  ./charts/maas-code-assistant/render.sh
fi

# Install all dependency operators, and create the DataScienceCluster for RHOAI
noisy helm upgrade --install --timeout 15m0s \
  dependency-operators charts/dependency-operators \
  -f charts/maas-code-assistant/all-dependencies.yaml
noisy oc wait --for=condition=Ready datasciencecluster default-dsc --timeout 15m0s

# Install the chart
noisy -c "$ADMIN_PASSWORD" -c "$USER_PASSWORD" helm upgrade --install -n default --timeout 20m0s \
  maas-code-assistant charts/maas-code-assistant \
  -f charts/maas-code-assistant/all-dependencies.yaml \
  --set keycloak.realm.admin.password="$ADMIN_PASSWORD" \
  --set keycloak.realm.user.password="$USER_PASSWORD"
