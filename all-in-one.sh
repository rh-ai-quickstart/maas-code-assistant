#!/bin/bash

set -e
cd "$(dirname "$(realpath "$0")")"

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

# Render values from the cluster (router wildcard domain and default certificate name)
if ! [ -e dev-preview/kustomization.yaml ]; then
  ./dev-preview/render.sh
fi
if ! [ -e charts/maas-code-assistant/all-dependencies.yaml ]; then
  ./charts/maas-code-assistant/render.sh
fi

# Install all dependency operators, and create the DataScienceCluster for RHOAI
noisy helm upgrade --install dependency-operators charts/dependency-operators --timeout 15m0s
noisy oc wait --for=condition=Ready datasciencecluster default-dsc

# Install the maas-api project for the dev preview
if ! oc get ns maas-api >/dev/null 2>&1; then
  noisy oc create ns maas-api
fi
noisy oc apply -k dev-preview
noisy oc rollout status deployment maas-api -n maas-api

if [ -r .env ]; then
  . .env
fi
if [ -z "$ADMIN_PASSWORD" ]; then
  read -rsp 'Enter a password for the admin user: ' ADMIN_PASSWORD
fi
echo
if [ -z "$USER_PASSWORD" ]; then
  read -rsp 'Enter a password for the generated users: ' USER_PASSWORD
fi
echo

# Install the chart
noisy -c "$ADMIN_PASSWORD" -c "$USER_PASSWORD" helm upgrade --install -n default --timeout 20m0s \
  maas-code-assistant charts/maas-code-assistant \
  -f charts/maas-code-assistant/all-dependencies.yaml \
  --set keycloak.realm.admin.password="$ADMIN_PASSWORD" \
  --set keycloak.realm.user.password="$USER_PASSWORD"
