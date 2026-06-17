#!/bin/bash

set -ex

rhcl_operators=(
  authorino
  dns
  limitador
  rhcl
)

operator_namespace={{ (index (index $.Values "install-operators").operators "rhcl-operator").namespace | default "openshift-operators" }}

function operator_ready {
  installed_version="$(oc get -n $operator_namespace subscription -l "operators.coreos.com/${1}-operator.${operator_namespace}" -ojsonpath='{.items[0].status.state}' 2>&1)" ||:
  if [ "$installed_version" != "" ]; then
    return 0
  else
    return 1
  fi
}

for operator in "${rhcl_operators[@]}"; do
  if ! operator_ready "$operator"; then
    sleep 1
  fi
done
echo

oc delete pod -l app=kuadrant,control-plane=controller-manager
sleep 1
oc rollout status deployment/kuadrant-operator-controller-manager
oc apply -f kuadrant.yaml
sleep 1
oc wait --for=condition=Ready kuadrant kuadrant --timeout 15m0s
sleep 1
oc annotate service authorino-authorino-authorization service.beta.openshift.io/serving-cert-secret-name=authorino-server-cert --overwrite
sleep 1
oc patch authorino authorino --type=merge --patch '{"spec": {"listener": {"tls": {"enabled": true, "certSecretRef": {"name": "authorino-server-cert"}}}}}'
sleep 1
oc set env deployment/authorino SSL_CERT_FILE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt REQUESTS_CA_BUNDLE=/etc/ssl/certs/openshift-service-ca/service-ca-bundle.crt
sleep 1
oc rollout status deployment/authorino --timeout=5m
