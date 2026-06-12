#!/bin/bash

set -ex

oc patch odhdashboardconfig odh-dashboard-config --patch-file=odhdashboardconfig.yaml --type=merge

oc delete pods -l app=rhods-dashboard
sleep 1
oc rollout status deploy/rhods-dashboard
