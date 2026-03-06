#!/bin/bash

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

cd "$(dirname "$(realpath "$0")")"

eval "cat << EOF > all-dependencies.yaml
$(<all-dependencies.yaml.tpl)
EOF
"

echo "${PWD}/all-dependencies.yaml:"
sed 's/^/  /' all-dependencies.yaml
