#!/bin/bash

set -ex 

. scripts/include/common.sh
. .envrc

exec kubectl port-forward -n default pod/socksproxy ${KUBEPROXY_PORT}:8000
