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
# TODO
git checkout feature/eks-terrform-12

# terraform needs helm client installed and configured:
helm init --client-only

EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-$(whoami)-cap}"
EKS_LOCATION="${GKE_LOCATION:-us-west-2}"
EKS_KEYPAIR="${EKS_KEYPAIR:-$(whoami)-terraform}"
cat <<HEREDOC > terraform.tfvars
cluster-name = "$EKS_CLUSTER_NAME"
region = "$EKS_LOCATION"
keypair_name = "$EKS_KEYPAIR"
workstation_cidr_block = "0.0.0.0/0"
HEREDOC

terraform init

terraform plan -out=my-plan

terraform apply -auto-approve

# get kubectl for eks:
# aws eks --region "$EKS_LOCATION" update-kubeconfig --name "$EKS_CLUSTER_NAME"
# or:
terraform output kubeconfig > "$KUBECONFIG"

# make worker nodes join:
terraform output config_map_aws_auth > eks_cm.yaml
kubectl apply -f eks_cm.yaml

# wait for workers:
while kubectl get nodes | grep "notReady" > /dev/null;
do
    sleep 10
done

# test deployment:
kubectl get svc

ROOTFS=overlay-xfs
# take first worker node as public ip:
PUBLIC_IP="$(kubectl get nodes -o json | jq -r '.items[].status.addresses[] | select(.type == "InternalIP").address' | head -n 1)"
DOMAIN="$PUBLIC_IP.omg.howdoi.website"
if ! kubectl get configmap -n kube-system 2>/dev/null | grep -qi cap-values; then
    kubectl create configmap -n kube-system cap-values \
            --from-literal=garden-rootfs-driver="${ROOTFS}" \
            --from-literal=public-ip="${PUBLIC_IP}" \
            --from-literal=domain="${DOMAIN}" \
            --from-literal=platform=eks
fi

create_rolebinding() {

    kubectl create clusterrolebinding admin --clusterrole=cluster-admin --user=system:serviceaccount:kube-system:default
    kubectl create clusterrolebinding uaaadmin --clusterrole=cluster-admin --user=system:serviceaccount:uaa:default
    kubectl create clusterrolebinding scfadmin --clusterrole=cluster-admin --user=system:serviceaccount:scf:default

    kubectl apply -f - <<HEREDOC
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: cluster-admin
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-system:default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: kube-system
HEREDOC
}
create_rolebinding
