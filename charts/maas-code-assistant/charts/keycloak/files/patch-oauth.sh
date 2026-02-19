#!/bin/bash

set -ex

oc patch oauth cluster --patch-file=oauth.yaml --type=merge
