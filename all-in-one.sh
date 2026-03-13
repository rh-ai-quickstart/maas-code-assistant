#!/bin/bash

set -e
cd "$(dirname "$(realpath "$0")")"

if [ "$(oc get storageclass -ogo-template='{{ range .items }}{{ if .metadata.annotations }}{{ if eq (index .metadata.annotations "storageclass.kubernetes.io/is-default-class") "true" }}found{{ break }}{{ end }}{{ end }}{{ end }}')" != "found" ]; then
  echo 'You do not have a default StorageClass. This deployment requires persistent storage. Check the documentation.' >&2
  exit 1
fi

if [ -r .env ]; then
  . .env
fi
if [ -z "$ADMIN_PASSWORD" ]; then
  read -rsp 'Enter a password to set for the admin user (will be created): ' ADMIN_PASSWORD
  echo
  echo "ADMIN_PASSWORD=\"$ADMIN_PASSWORD\"" >> .env
fi
if [ -z "$USER_PASSWORD" ]; then
  read -rsp 'Enter a password to set for the generated users (user1-user5 by default): ' USER_PASSWORD
  echo
  echo "USER_PASSWORD=\"$USER_PASSWORD\"" >> .env
fi

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

INGRESS_DOMAIN=$(oc get ingresscontroller -n openshift-ingress-operator default -ojsonpath='{.status.domain}' 2>/dev/null)
if [ -z "$INGRESS_DOMAIN" ]; then
  echo "Unable to retrieve ingress configuration from your cluster." >&2
  echo "Are you logged in with oc?" >&2
  oc whoami
  exit 1
fi
export INGRESS_DOMAIN

INGRESS_CERTIFICATE=$(oc get ingresscontroller -n openshift-ingress-operator default -ojsonpath='{.spec.defaultCertificate.name}' 2>/dev/null)
if [ -z "$INGRESS_CERTIFICATE" ]; then
  INGRESS_CERTIFICATE=router-certs-default
  INGRESS_CA="$(oc get secret -n openshift-ingress-operator router-ca -ogo-template='{{ index .data "tls.crt" | base64decode }}')"
else
  INGRESS_CA=""
fi
export INGRESS_CERTIFICATE INGRESS_CA

if [ "$(oc get config.imageregistry cluster -ogo-template='{{ range .status.conditions }}{{ if eq .type "Available" }}{{ .status }}{{ end }}{{ end }}')" = "True" ]; then
  TOOLS_IMAGE=image-registry.openshift-image-registry.svc:5000/openshift/tools:latest
else
  TOOLS_IMAGE=quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:e850f92068d8365e68bab663ae7b76be22c0af33f6a7803c5c95f5ee3f3748f4
fi
export TOOLS_IMAGE

function gateway_use_route {
    ret=1
    if ! oc get svc -n openshift-ingress router-default >/dev/null 2>&1; then
        ret=0
    fi
    if [ "$(oc get svc -n openshift-ingress router-default -ojsonpath='{.spec.type}')" != "LoadBalancer" ]; then
        ret=0
    fi
    if [ "$ret" -ne 1 ]; then
        echo "WARNING: Detected a non-load-balancer ingress configuration. Using a Route to back Gateway API resources." >&2
    fi
    return $ret
}
if gateway_use_route; then
    GATEWAY_USE_ROUTE=true
else
    GATEWAY_USE_ROUTE=false
fi
export GATEWAY_USE_ROUTE

eval "cat << EOF > environment.yaml
$(<environment.yaml.tpl)
EOF
"

# Install all dependency operators, and create the DataScienceCluster for RHOAI
noisy helm upgrade --install --timeout 15m0s \
  dependency-operators charts/dependency-operators \
  -f environment.yaml
noisy oc wait --for=condition=Ready datasciencecluster default-dsc --timeout 15m0s

# Install the chart
noisy -c "$ADMIN_PASSWORD" -c "$USER_PASSWORD" helm upgrade --install -n default --timeout 20m0s \
  maas-code-assistant charts/maas-code-assistant \
  -f charts/maas-code-assistant/all-dependencies.yaml \
  -f environment.yaml \
  --set keycloak.realm.admin.password="$ADMIN_PASSWORD" \
  --set keycloak.realm.user.password="$USER_PASSWORD"
