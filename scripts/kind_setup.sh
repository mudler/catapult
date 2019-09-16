#!/bin/bash
set -x

. scripts/include/common.sh
. .envrc

kubectl create clusterrolebinding admin --clusterrole=cluster-admin --user=system:serviceaccount:kube-system:default
kubectl create clusterrolebinding uaaadmin --clusterrole=cluster-admin --user=system:serviceaccount:uaa:default
kubectl create clusterrolebinding scfadmin --clusterrole=cluster-admin --user=system:serviceaccount:scf:default

cat > storageclass.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hostpath-provisioner
  namespace: kube-system
---

kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: hostpath-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["list", "watch", "create", "update", "patch"]
---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: hostpath-provisioner
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: hostpath-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: hostpath-provisioner
  apiGroup: rbac.authorization.k8s.io
---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: Role
metadata:
  name: hostpath-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "get", "delete"]
---

apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: hostpath-provisioner
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: hostpath-provisioner
subjects:
- kind: ServiceAccount
  name: hostpath-provisioner
---

# -- Create a pod in the kube-system namespace to run the host path provisioner
apiVersion: v1
kind: Pod
metadata:
  namespace: kube-system
  name: hostpath-provisioner
spec:
  serviceAccountName: hostpath-provisioner
  containers:
    - name: hostpath-provisioner
      image: mazdermind/hostpath-provisioner:latest
      imagePullPolicy: "IfNotPresent"
      env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: PV_DIR
          value: /mnt/kubernetes-pv-manual

      volumeMounts:
        - name: pv-volume
          mountPath: /mnt/kubernetes-pv-manual
  volumes:
    - name: pv-volume
      hostPath:
        path: /mnt/kubernetes-pv-manual
---

# -- Create the standard storage class for running on-node hostpath storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  namespace: kube-system
  name: persistent
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: EnsureExists
provisioner: hostpath
EOF

kubectl delete storageclass standard
kubectl create -f ../kube/storageclass.yaml
helm init --upgrade --wait

if [ -n "$EKCP_HOST" ]; then
    container_ip=$(curl -s http://$EKCP_HOST/ | jq .ClusterIPs.${CLUSTER_NAME} -r)
    domain="${CLUSTER_NAME}.${container_ip}.${EKCP_DOMAIN}"
else
    container_id=$(docker ps -f "name=${cluster_name}-control-plane" -q)
    container_ip=$(docker inspect $container_id | jq -r .[0].NetworkSettings.Networks.bridge.IPAddress)
    domain="${container_ip}.nip.io"
fi

if ! kubectl get configmap -n kube-system 2>/dev/null | grep -qi cap-values; then
    kubectl create configmap -n kube-system cap-values \
            --from-literal=public-ip="${container_ip}" \
            --from-literal=domain="$domain" \
            --from-literal=platform="kind"
fi
