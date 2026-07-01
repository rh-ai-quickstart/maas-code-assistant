#!/bin/bash

set -ex

cd "$(dirname "$(realpath "$0")")"

oc apply -f gatewayclass.yaml
oc apply -f gateway.yaml
{{- with $db := .Values.postgresCluster }}
{{- if $db.create }}

oc rollout status -n cloudnative-pg deployment/cnpg-controller-manager
sleep 5
oc apply -f cluster.yaml
while ! [ "$(oc get cluster -n {{ $db.namespace }} {{ $db.name }} -o jsonpath='{.status.readyInstances}')" -eq "{{ $db.instances | default 1 }}" ]; do
  sleep 5
done
uri=$(oc get secret -n {{ $db.namespace }} {{ $db.name }}-app -ojsonpath='{.data.uri}' | base64 -d)
oc create secret generic maas-db-config -n redhat-ods-applications --from-literal=DB_CONNECTION_URL="$uri" --dry-run=client -oyaml | oc apply -f-
{{- end }}
{{- end }}

oc apply -f dscinitialization.yaml
while ! oc apply -f datasciencecluster.yaml; do
  sleep 5
done
