#!/bin/bash

set -ex

oc patch odhdashboardconfig odh-dashboard-config --patch-file=odhdashboardconfig.yaml --type=merge

oc rollout restart deployment/rhods-dashboard
oc rollout status deploy/rhods-dashboard
