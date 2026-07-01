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


function find_install_plan {
  oc get installplan -ogo-template='
    {{ "{{-" }} range $ip := .items {{ "}}" }}
      {{ "{{-" }} range .spec.clusterServiceVersionNames {{ "}}" }}
        {{ "{{-" }} if eq . "{{ $config.startingCSV }}" {{ "}}" }}
          {{ "{{-" }} if $ip.status {{ "}}" }}
            {{ "{{-" }} if or (eq $ip.status.phase "RequiresApproval") (eq $ip.status.phase "Complete") {{ "}}" }}
              {{ "{{-" }} $ip.metadata.name {{ "}}{{" }} break {{ "}}" }}
            {{ "{{-" }} end {{ "}}" }}
          {{ "{{-" }} end {{ "}}" }}
        {{ "{{-" }} end {{ "}}" }}
      {{ "{{-" }} end {{ "}}" }}
    {{ "{{-" }} end {{ "}}" }}' 2>/dev/null
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
