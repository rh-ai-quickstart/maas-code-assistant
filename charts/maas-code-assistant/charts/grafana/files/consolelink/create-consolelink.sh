#!/bin/bash

set -ex

route=$(oc get route grafana-route -ojsonpath='{.status.ingress[0].host}')
export route

cat << EOF | oc apply -f-
$(cat /mnt/consolelink.yaml.tpl)
  href: https://${route}/
EOF
