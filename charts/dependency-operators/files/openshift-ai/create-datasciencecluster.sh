#!/bin/bash

set -ex

cd "$(dirname "$(realpath "$0")")"

oc apply -f gatewayclass.yaml
oc apply -f gateway.yaml
while ! oc apply -f datasciencecluster.yaml; do
  sleep 5
done
