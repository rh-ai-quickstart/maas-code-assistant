#!/bin/bash

set -e

sleep 30

oc delete pod -l app=kuadrant,control-plane=controller-manager
sleep 1
oc rollout status deployment/kuadrant-operator-controller-manager
