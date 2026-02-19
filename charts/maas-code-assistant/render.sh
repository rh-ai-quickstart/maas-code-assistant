#!/bin/bash

INGRESS_CERTIFICATE=$(oc get ingresscontroller -n openshift-ingress-operator default -ojsonpath='{.spec.defaultCertificate.name}' 2>/dev/null)
INGRESS_DOMAIN=$(oc get ingresscontroller -n openshift-ingress-operator default -ojsonpath='{.status.domain}' 2>/dev/null)
export INGRESS_CERTIFICATE INGRESS_DOMAIN

if [ -z "$INGRESS_CERTIFICATE" ] || [ -z "$INGRESS_DOMAIN" ]; then
  echo "Unable to retrieve ingress configuration from your cluster." >&2
  echo "Are you logged in with oc, and do you have a valid wildcard certificate configured for the router?" >&2
  exit 1
fi

cd "$(dirname "$(realpath "$0")")"

eval "cat << EOF > all-dependencies.yaml
$(<all-dependencies.yaml.tpl)
EOF
"

echo "${PWD}/all-dependencies.yaml:"
sed 's/^/  /' all-dependencies.yaml
