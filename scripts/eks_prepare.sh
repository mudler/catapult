#!/usr/bin/env bash

. scripts/include/common.sh
. .envrc

set -Eexuo pipefail


kubectl apply -f - <<HEREDOC
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: persistent
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
HEREDOC
