#!/bin/bash

set -ex

cd "$(dirname "$(realpath "$0")")"

while ! oc apply -f datasciencecluster.yaml; do
  sleep 5
done
