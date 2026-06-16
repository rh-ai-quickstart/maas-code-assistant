#!/bin/bash

{{- $operator := index . 0 }}
{{- $config := index . 1 }}

set -ex

function approve_install_plan {
  installplan=$1
  set -x
  oc patch installplan $installplan --patch '{"spec": {"approved": true}}' --type merge
  { set +x ; } 2>/dev/null
}

# Shorten the label until it fits
label={{ $operator }}.{{ $config.namespace | default "openshift-operators" }}
while [ "$(echo -n "$label" | wc -c)" -gt 63 ]; do
  label="$(echo "$label" | rev | cut -d- -f2- | rev)"
done
echo $label

function find_install_plan {
  oc get installplan -l "operators.coreos.com/$label" -ojsonpath='{.items[?(@.spec.clusterServiceVersionNames contains "{{ $config.startingCSV }}")].metadata.name}' 2>/dev/null
}

while true; do
  install_plan=$(find_install_plan)
  if [ "$install_plan" ]; then
    echo
    approve_install_plan "$install_plan"
    break
  fi
  sleep 1
done
