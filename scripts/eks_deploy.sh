#!/usr/bin/env bash

# Requires:
# - aws credentials present

. scripts/include/common.sh
. .envrc

set -Eexuo pipefail

if ! aws sts get-caller-identity ; then
    echo ">>> Missing aws credentials, run aws configure, aborting" && exit 1
fi

git clone https://github.com/SUSE/cap-terraform.git
pushd cap-terraform/eks
git checkout viccuad-eks

cluster_name=vic-test2
# cluster_name=$(whoami)-"$CLUSTER_NAME"
location="us-west-2"
keypair=viccuad
subnet_count=3

terraform init
cat <<HEREDOC > terraform.tfvars
subnet_count = "$subnet_count"
cluster_name = "$cluster_name"
location = "$location"
keypair_name = "$keypair"
HEREDOC

terraform plan --out=my-plan

terraform apply

# get kubectl for eks:
# aws eks --region "$location" update-kubeconfig --name "$cluster_name"
aws eks --region us-west-2 update-kubeconfig --name vic-test2

# test deployment:
kubectl get svc

ROOTFS=overlay-xfs
PUBLIC_IP="TODO"
DOMAIN="TODO"
if ! kubectl get configmap -n kube-system 2>/dev/null | grep -qi cap-values; then
    kubectl create configmap -n kube-system cap-values \
            --from-literal=garden-rootfs-driver="${ROOTFS}" \
            --from-literal=public-ip="${PUBLIC_IP}" \
            --from-literal=domain="${DOMAIN}" \
            --from-literal=platform=eks
fi

