#!/bin/bash

set -ex

while ! oc patch authpolicy maas-default-gateway-authn --patch-file=authpolicy-maas-default-gateway.yaml --type=merge; do
  sleep 10
done
