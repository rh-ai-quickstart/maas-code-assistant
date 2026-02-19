#!/bin/bash

set -ex

oc patch odhdashboardconfig odh-dashboard-config --patch-file=odhdashboardconfig.yaml --type=merge
